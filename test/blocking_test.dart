import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/shared/blocking/models/blocked_user.dart';
import 'package:myglo/src/features/shared/blocking/models/blocks_repository.dart';
import 'package:myglo/src/features/shared/blocking/views/block_user_dialog.dart';
import 'package:myglo/src/features/shared/blocking/views/blocked_accounts_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps blocks in memory instead of calling the server.
class _FakeBlocks implements BlocksRepository {
  _FakeBlocks([List<BlockedUser>? users]) : users = [...?users];

  final List<BlockedUser> users;
  final blocked = <String>[];
  final unblocked = <String>[];
  Object? failWith;

  @override
  Future<void> block(String userId) async {
    if (failWith != null) throw BlockFailure.from(failWith!);
    blocked.add(userId);
  }

  @override
  Future<void> unblock(String userId) async {
    if (failWith != null) throw BlockFailure.from(failWith!);
    unblocked.add(userId);
    users.removeWhere((u) => u.userId == userId);
  }

  @override
  Future<List<BlockedUser>> list() async => List.of(users);
}

BlockedUser _user(String id, String name, {String role = 'customer'}) =>
    BlockedUser(userId: id, displayName: name, role: role, blockedAt: DateTime.utc(2026, 11, 20));

Widget _app(Widget child, _FakeBlocks repo) => ProviderScope(
      overrides: [blocksRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(theme: AppTheme.lightTheme, home: child),
    );

/// A button that opens the block confirmation for "Glow Studio".
class _BlockButton extends ConsumerWidget {
  const _BlockButton(this.onResult);

  final ValueChanged<bool> onResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: TextButton(
          onPressed: () async => onResult(await confirmAndBlockUser(context, ref, userId: 'p-1', name: 'Glow Studio')),
          child: const Text('block'),
        ),
      );
}

void main() {
  group('BlockedUser', () {
    test('reads the server row and falls back for a missing name', () {
      final user = BlockedUser.fromJson(const {
        'user_id': 'u-1',
        'display_name': '  ',
        'avatar_url': null,
        'role': 'provider',
        'blocked_at': '2026-11-20T10:00:00+00:00',
      });
      expect(user.displayName, 'Myglo member');
      expect(user.isProvider, isTrue);
    });
  });

  group('BlockFailure', () {
    test('explains refusals the user can act on', () {
      expect(BlockFailure.from(const PostgrestException(message: 'too_many_blocks')).message, contains('Unblock someone'));
      expect(BlockFailure.from(const PostgrestException(message: 'user_not_found')).message, contains('no longer exists'));
      expect(BlockFailure.from(const SocketException('x')).message, contains('offline'));
    });

    test('anything else is unexpected and never shows server text', () {
      final failure = BlockFailure.from(const PostgrestException(message: 'pq: internal'));
      expect(failure.expected, isFalse);
      expect(failure.message, 'Something went wrong. Please try again.');
    });
  });

  group('confirmAndBlockUser', () {
    testWidgets('asks first, and Cancel blocks nobody', (tester) async {
      final repo = _FakeBlocks();
      bool? result;
      await tester.pumpWidget(_app(_BlockButton((r) => result = r), repo));

      await tester.tap(find.text('block'));
      await tester.pumpAndSettle();
      expect(find.text('Block Glow Studio?'), findsOneWidget);
      expect(find.textContaining("They won't be told."), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.blocked, isEmpty);
      expect(result, isFalse);
    });

    testWidgets('confirming blocks and says so', (tester) async {
      final repo = _FakeBlocks();
      bool? result;
      await tester.pumpWidget(_app(_BlockButton((r) => result = r), repo));

      await tester.tap(find.text('block'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await tester.pumpAndSettle();

      expect(repo.blocked, ['p-1']);
      expect(result, isTrue);
      expect(find.text('Glow Studio is blocked'), findsOneWidget);
    });

    testWidgets('a refusal is explained and reported as not blocked', (tester) async {
      final repo = _FakeBlocks()..failWith = const PostgrestException(message: 'too_many_blocks');
      bool? result;
      await tester.pumpWidget(_app(_BlockButton((r) => result = r), repo));

      await tester.tap(find.text('block'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.textContaining('Unblock someone'), findsOneWidget);
    });
  });

  group('BlockedAccountsScreen', () {
    testWidgets('explains itself when nobody is blocked', (tester) async {
      await tester.pumpWidget(_app(const BlockedAccountsScreen(), _FakeBlocks()));
      await tester.pumpAndSettle();

      expect(find.text('Nobody blocked'), findsOneWidget);
    });

    testWidgets('lists blocked accounts and unblocks after confirming', (tester) async {
      final repo = _FakeBlocks([
        _user('p-1', 'Glow Studio', role: 'provider'),
        _user('c-1', 'Mia Tran'),
      ]);
      await tester.pumpWidget(_app(const BlockedAccountsScreen(), repo));
      await tester.pumpAndSettle();

      expect(find.text('Glow Studio'), findsOneWidget);
      expect(find.text('Mia Tran'), findsOneWidget);
      expect(find.textContaining('Provider · blocked'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Unblock').first);
      await tester.pumpAndSettle();
      expect(find.text('Unblock Glow Studio?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Unblock'));
      await tester.pumpAndSettle();

      expect(repo.unblocked, ['p-1']);
      expect(find.text('Glow Studio'), findsNothing);
      expect(find.text('Mia Tran'), findsOneWidget);
    });
  });
}
