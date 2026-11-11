import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myglo/src/core/config/app_config.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/shared/authentication/models/auth_error_messages.dart';
import 'package:myglo/src/features/shared/authentication/models/auth_repository.dart';
import 'package:myglo/src/features/shared/authentication/views/screens/reset_password_screen.dart';
import 'package:myglo/src/features/shared/authentication/views/widgets/email_code_entry.dart';
import 'package:myglo/src/features/shared/authentication/views/widgets/password_setup_form.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const _email = 'mia@example.com';
const _newPassword = 'correct-horse-9';
final _code = '1' * AppConfig.emailOtpLength;

final _user = User(
  id: 'user-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  email: _email,
  createdAt: DateTime(2026).toIso8601String(),
);

/// Opens the reset screen the way the app does: pushed over sign-in (signed
/// out) or over settings ([signedIn]).
Future<_MockAuthRepository> _pump(
  WidgetTester tester, {
  bool signedIn = false,
  String email = _email,
  void Function(_MockAuthRepository repo)? arrange,
}) async {
  final repo = _MockAuthRepository();
  when(() => repo.currentUser).thenReturn(signedIn ? _user : null);
  when(() => repo.sendPasswordResetCode(any())).thenAnswer((_) async {});
  when(() => repo.verifyPasswordResetCode(email: any(named: 'email'), code: any(named: 'code')))
      .thenAnswer((_) async => AuthResponse(user: _user));
  when(() => repo.updatePassword(any())).thenAnswer((_) async {});
  arrange?.call(repo);

  final router = GoRouter(
    initialLocation: '/origin',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('SPLASH'))),
      GoRoute(
        path: '/origin',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.push(Uri(path: '/reset-password', queryParameters: {'email': email}).toString()),
            child: const Text('open'),
          ),
        ),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => ResetPasswordScreen(email: state.uri.queryParameters['email'] ?? ''),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ),
  );
  await tester.tap(find.text('open'));
  await _settle(tester);
  return repo;
}

/// The code field's cursor and the resend countdown never stop, so frames
/// are pumped for a fixed time instead of until idle.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _enterCode(WidgetTester tester, String code) async {
  await tester.enterText(find.descendant(of: find.byType(EmailCodeEntry), matching: find.byType(EditableText)), code);
  await tester.pump();
  await tester.pump();
}

Future<void> _choosePassword(WidgetTester tester, String password, {String? confirm}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), password);
  await tester.enterText(fields.at(1), confirm ?? password);
  await tester.tap(find.text('Save password'));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('AuthErrorMessages.forPasswordUpdate', () {
    test('explains a weak or reused password', () {
      expect(
        AuthErrorMessages.forPasswordUpdate(const AuthException('Password is known to be weak', code: 'weak_password')),
        AuthErrorMessages.weakPassword,
      );
      expect(
        AuthErrorMessages.forPasswordUpdate(const AuthException('New password should be different', code: 'same_password')),
        AuthErrorMessages.samePassword,
      );
    });

    test('never shows raw server text', () {
      expect(AuthErrorMessages.forPasswordUpdate(const AuthException('pq: something internal')), AuthErrorMessages.generic);
      expect(AuthErrorMessages.forPasswordUpdate(const SocketException('x')), AuthErrorMessages.offline);
      expect(AuthErrorMessages.forPasswordUpdate(StateError('x')), AuthErrorMessages.generic);
    });

    test('a lost session needs a new code', () {
      const gone = AuthException('Session not found', code: 'session_not_found');
      expect(AuthErrorMessages.needsNewCode(gone), isTrue);
      expect(AuthErrorMessages.forPasswordUpdate(gone), AuthErrorMessages.sessionExpired);
      expect(AuthErrorMessages.needsNewCode(const AuthException('weak', code: 'weak_password')), isFalse);
    });
  });

  group('ResetPasswordScreen', () {
    testWidgets('emails a code as it opens and asks for it', (tester) async {
      final repo = await _pump(tester);

      verify(() => repo.sendPasswordResetCode(_email)).called(1);
      expect(find.byType(EmailCodeEntry), findsOneWidget);
      expect(find.textContaining('Enter it below to choose a new password.'), findsOneWidget);
      expect(find.textContaining('Resend code in'), findsOneWidget);
      expect(find.byType(PasswordSetupForm), findsNothing);
    });

    testWidgets('forgotten password: code, new password, then into the app', (tester) async {
      final repo = await _pump(tester);

      await _enterCode(tester, _code);
      verify(() => repo.verifyPasswordResetCode(email: _email, code: _code)).called(1);
      expect(find.text('Choose a new password'), findsOneWidget);

      await _choosePassword(tester, _newPassword);
      await _settle(tester);

      verify(() => repo.updatePassword(_newPassword)).called(1);
      expect(find.text('SPLASH'), findsOneWidget);
    });

    testWidgets('change password from settings goes back to settings', (tester) async {
      final repo = await _pump(tester, signedIn: true);

      await _enterCode(tester, _code);
      await _choosePassword(tester, _newPassword);
      await _settle(tester);

      verify(() => repo.updatePassword(_newPassword)).called(1);
      expect(find.text('open'), findsOneWidget);
      expect(find.text('SPLASH'), findsNothing);
    });

    testWidgets('a wrong code is explained and can be retried', (tester) async {
      final repo = await _pump(
        tester,
        arrange: (repo) => when(() => repo.verifyPasswordResetCode(email: any(named: 'email'), code: any(named: 'code')))
            .thenThrow(const AuthException('Token has expired or is invalid', code: 'otp_expired')),
      );

      await _enterCode(tester, _code);

      expect(find.byKey(const Key('code_error')), findsOneWidget);
      expect(find.text(AuthErrorMessages.invalidCode), findsOneWidget);
      expect(find.byType(PasswordSetupForm), findsNothing);
      verifyNever(() => repo.updatePassword(any()));
    });

    testWidgets('a suspended account is told so', (tester) async {
      await _pump(
        tester,
        arrange: (repo) => when(() => repo.verifyPasswordResetCode(email: any(named: 'email'), code: any(named: 'code')))
            .thenThrow(const AuthException('User is banned', code: 'user_banned')),
      );

      await _enterCode(tester, _code);

      expect(find.text(AuthErrorMessages.suspended), findsOneWidget);
    });

    testWidgets('short or mismatched passwords are not sent', (tester) async {
      final repo = await _pump(tester);
      await _enterCode(tester, _code);

      await _choosePassword(tester, 'short7!');
      expect(find.text('Password must be at least ${AppConfig.passwordMinLength} characters'), findsOneWidget);

      await _choosePassword(tester, _newPassword, confirm: '$_newPassword!');
      expect(find.text('Passwords do not match'), findsOneWidget);

      verifyNever(() => repo.updatePassword(any()));
    });

    testWidgets('a password the server refuses keeps the form up with the reason', (tester) async {
      final repo = await _pump(
        tester,
        arrange: (repo) => when(() => repo.updatePassword(any()))
            .thenThrow(const AuthException('Password is known to be weak', code: 'weak_password')),
      );
      await _enterCode(tester, _code);

      await _choosePassword(tester, _newPassword);

      expect(find.text(AuthErrorMessages.weakPassword), findsOneWidget);
      expect(find.byType(PasswordSetupForm), findsOneWidget);
      expect(find.text('SPLASH'), findsNothing);
      verify(() => repo.updatePassword(_newPassword)).called(1);
      // Let the snackbar's timer finish.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('if the session from the code is gone, it asks for a new code', (tester) async {
      await _pump(
        tester,
        arrange: (repo) => when(() => repo.updatePassword(any()))
            .thenThrow(const AuthException('Session not found', code: 'session_not_found')),
      );
      await _enterCode(tester, _code);

      await _choosePassword(tester, _newPassword);

      expect(find.byType(EmailCodeEntry), findsOneWidget);
      expect(find.text(AuthErrorMessages.sessionExpired), findsOneWidget);
    });

    testWidgets('a refused email shows the wait and still lets the code be entered', (tester) async {
      final repo = await _pump(
        tester,
        arrange: (repo) => when(() => repo.sendPasswordResetCode(any()))
            .thenThrow(const AuthException('slow down', statusCode: '429', code: 'over_email_send_rate_limit')),
      );

      verify(() => repo.sendPasswordResetCode(_email)).called(1);
      expect(find.text(AuthErrorMessages.rateLimited), findsOneWidget);
      expect(find.textContaining('Resend code in'), findsOneWidget);
      expect(find.byType(EmailCodeEntry), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('resend is offered once the wait is over', (tester) async {
      final repo = await _pump(tester);

      await tester.pump(AppConfig.otpResendCooldown + const Duration(seconds: 1));
      await tester.tap(find.text("Didn't get it? Resend code"));
      await tester.pump();
      await tester.pump();

      verify(() => repo.sendPasswordResetCode(_email)).called(2);
      expect(find.text('A new code is on its way.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('without an address nothing is sent', (tester) async {
      final repo = await _pump(tester, email: '');

      verifyNever(() => repo.sendPasswordResetCode(any()));
      expect(find.textContaining("We don't know which account"), findsOneWidget);
      expect(find.byType(EmailCodeEntry), findsNothing);
    });
  });
}
