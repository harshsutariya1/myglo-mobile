import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/core/utils/formatters.dart';
import 'package:myglo/src/features/shared/account_deletion/controllers/account_deletion_controller.dart';
import 'package:myglo/src/features/shared/account_deletion/models/account_deletion_repository.dart';
import 'package:myglo/src/features/shared/account_deletion/models/account_deletion_status.dart';
import 'package:myglo/src/features/shared/account_deletion/views/delete_account_screen.dart';
import 'package:myglo/src/features/shared/authentication/controllers/session_actions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Records calls instead of reaching Supabase.
class _FakeRepository implements AccountDeletionRepository {
  _FakeRepository({this.passwordFailure, this.deleteFailure});

  final AccountDeletionFailure? passwordFailure;
  final AccountDeletionFailure? deleteFailure;
  final passwords = <String>[];
  var deletes = 0;

  @override
  Future<AccountDeletionStatus> getStatus() async => const AccountDeletionStatus(role: 'customer');

  @override
  Future<void> confirmPassword(String password) async {
    passwords.add(password);
    if (passwordFailure != null) throw passwordFailure!;
  }

  @override
  Future<void> deleteAccount() async {
    deletes++;
    if (deleteFailure != null) throw deleteFailure!;
  }
}

class _FakeSessionActions implements SessionActions {
  var signedOutAfterDeletion = 0;

  @override
  Future<void> signOutAfterAccountDeletion() async => signedOutAfterDeletion++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
  WidgetTester tester, {
  required AccountDeletionStatus status,
  _FakeRepository? repository,
  _FakeSessionActions? session,
}) async {
  final router = GoRouter(
    initialLocation: '/delete',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Text('splash'))),
      GoRoute(path: '/delete', builder: (context, state) => const DeleteAccountScreen()),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountDeletionStatusProvider.overrideWith((ref) async => status),
        accountDeletionRepositoryProvider.overrideWithValue(repository ?? _FakeRepository()),
        sessionActionsProvider.overrideWithValue(session ?? _FakeSessionActions()),
      ],
      child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterPasswordAndConfirm(WidgetTester tester, String password) async {
  await tester.enterText(find.byKey(const ValueKey('delete-account-password')), password);
  await tester.pump();
  await tester.ensureVisible(find.byKey(const ValueKey('delete-account-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('delete-account-button')));
  await tester.pumpAndSettle();
  expect(find.text('Delete your account?'), findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
  // The button's spinner keeps running under the result dialog, so step
  // frames instead of settling.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('AccountDeletionStatus', () {
    test('parses the status and its blockers', () {
      final status = AccountDeletionStatus.fromJson({
        'role': 'provider',
        'has_payout_account': true,
        'blockers': [
          {'code': 'upcoming_bookings', 'count': 2},
          {'code': 'something_new', 'count': 1},
        ],
      });

      expect(status.isProvider, isTrue);
      expect(status.hasPayoutAccount, isTrue);
      expect(status.canDelete, isFalse);
      expect(status.blockers.map((b) => b.code), [
        AccountDeletionBlockerCode.upcomingBookings,
        AccountDeletionBlockerCode.unknown,
      ]);
      expect(status.blockers.first.title, '2 upcoming bookings');
    });

    test('an empty status can be deleted', () {
      final status = AccountDeletionStatus.fromJson({'role': 'customer', 'blockers': <Object>[]});
      expect(status.canDelete, isTrue);
      expect(status.isProvider, isFalse);
      expect(status.hasPayoutAccount, isFalse);
    });

    test('blocker wording', () {
      expect(const AccountDeletionBlocker(code: AccountDeletionBlockerCode.upcomingBookings).title, '1 upcoming booking');
      expect(
        const AccountDeletionBlocker(code: AccountDeletionBlockerCode.stripeBalance, amountCents: 4550).message,
        contains(Formatters.audCents(4550)),
      );
      expect(
        const AccountDeletionBlocker(code: AccountDeletionBlockerCode.payoutsPending, count: 3).message,
        startsWith('3 completed bookings'),
      );
      expect(const AccountDeletionBlocker(code: AccountDeletionBlockerCode.accountSuspended).message, contains('@'));
    });
  });

  group('AccountDeletionFailure.from', () {
    AccountDeletionFailure fn(int status, Object? details) =>
        AccountDeletionFailure.from(FunctionException(status: status, details: details));

    test('maps the delete-account function errors', () {
      final blocked = fn(409, {
        'error': 'deletion_blocked',
        'blockers': [
          {'code': 'stripe_balance', 'amount_cents': 1200},
        ],
      });
      expect(blocked.code, AccountDeletionFailureCode.blocked);
      expect(blocked.blockers.single.code, AccountDeletionBlockerCode.stripeBalance);
      expect(blocked.blockers.single.amountCents, 1200);

      expect(fn(403, {'error': 'reauth_required'}).code, AccountDeletionFailureCode.reauthRequired);
      expect(fn(401, {'error': 'not_authenticated'}).code, AccountDeletionFailureCode.signedOut);
      expect(fn(502, {'error': 'deletion_unavailable'}).code, AccountDeletionFailureCode.unavailable);
      expect(fn(404, null).code, AccountDeletionFailureCode.unavailable);
      expect(fn(400, 'bad').code, AccountDeletionFailureCode.unknown);
    });

    test('maps password and network errors', () {
      expect(
        AccountDeletionFailure.from(const AuthException('Invalid login credentials', code: 'invalid_credentials')).code,
        AccountDeletionFailureCode.wrongPassword,
      );
      expect(
        AccountDeletionFailure.from(const AuthException('Too many', statusCode: '429')).code,
        AccountDeletionFailureCode.tooManyAttempts,
      );
      expect(
        AccountDeletionFailure.from(const SocketException('Failed host lookup')).code,
        AccountDeletionFailureCode.offline,
      );
    });

    test('only outages are unexpected', () {
      expect(const AccountDeletionFailure(AccountDeletionFailureCode.wrongPassword).isExpected, isTrue);
      expect(const AccountDeletionFailure(AccountDeletionFailureCode.unavailable).isExpected, isFalse);
    });
  });

  group('DeleteAccountScreen', () {
    testWidgets('lists blockers instead of the delete form', (tester) async {
      await _pump(
        tester,
        status: const AccountDeletionStatus(
          role: 'provider',
          blockers: [AccountDeletionBlocker(code: AccountDeletionBlockerCode.payoutsPending)],
        ),
      );

      expect(find.text('Before you can delete'), findsOneWidget);
      expect(find.text('Payouts on the way'), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-account-password')), findsNothing);
      expect(find.byKey(const ValueKey('delete-account-button')), findsNothing);
    });

    testWidgets('tells providers their payouts account closes too', (tester) async {
      await _pump(tester, status: const AccountDeletionStatus(role: 'provider', hasPayoutAccount: true));

      expect(find.textContaining('Stripe payouts account is closed'), findsOneWidget);
      expect(find.textContaining("Your business name stays on clients' receipts"), findsOneWidget);
    });

    testWidgets('needs a password before deleting', (tester) async {
      await _pump(tester, status: const AccountDeletionStatus(role: 'customer'));

      final button = find.byKey(const ValueKey('delete-account-button'));
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('delete-account-password')), 'secret');
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    });

    testWidgets('a wrong password shows on the field and deletes nothing', (tester) async {
      final repository = _FakeRepository(
        passwordFailure: const AccountDeletionFailure(AccountDeletionFailureCode.wrongPassword),
      );
      await _pump(tester, status: const AccountDeletionStatus(role: 'customer'), repository: repository);

      await _enterPasswordAndConfirm(tester, 'wrong');

      expect(repository.passwords, ['wrong']);
      expect(repository.deletes, 0);
      expect(find.text("That password isn't right."), findsOneWidget);
    });

    testWidgets('a late blocker from the server is shown', (tester) async {
      final repository = _FakeRepository(
        deleteFailure: const AccountDeletionFailure(
          AccountDeletionFailureCode.blocked,
          blockers: [AccountDeletionBlocker(code: AccountDeletionBlockerCode.stripeBalance, amountCents: 2500)],
        ),
      );
      await _pump(tester, status: const AccountDeletionStatus(role: 'provider'), repository: repository);

      await _enterPasswordAndConfirm(tester, 'secret');

      expect(find.text('Money in your Stripe balance'), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-account-button')), findsNothing);
    });

    testWidgets('deletes, confirms, then signs out', (tester) async {
      final repository = _FakeRepository();
      final session = _FakeSessionActions();
      await _pump(tester, status: const AccountDeletionStatus(role: 'customer'), repository: repository, session: session);

      await _enterPasswordAndConfirm(tester, 'secret');

      expect(repository.passwords, ['secret']);
      expect(repository.deletes, 1);
      expect(find.text('Account deleted'), findsOneWidget);
      expect(session.signedOutAfterDeletion, 0);

      await tester.tap(find.widgetWithText(FilledButton, 'OK'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(session.signedOutAfterDeletion, 1);
      expect(find.text('splash'), findsOneWidget);
    });
  });
}
