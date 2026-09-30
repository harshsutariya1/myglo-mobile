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
import 'package:myglo/src/features/shared/authentication/views/screens/email_confirmation_screen.dart';
import 'package:myglo/src/features/shared/authentication/views/widgets/email_code_entry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const _email = 'new.user+test@example.com';
final _code = '1' * AppConfig.emailOtpLength;

final _user = User(
  id: 'user-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  email: _email,
  createdAt: DateTime(2026).toIso8601String(),
);

Future<_MockAuthRepository> _pump(
  WidgetTester tester, {
  bool verifyOnly = false,
  void Function(_MockAuthRepository repo)? arrange,
}) async {
  final repo = _MockAuthRepository();
  when(() => repo.signUp(email: any(named: 'email'), password: any(named: 'password')))
      .thenAnswer((_) async => AuthResponse(user: _user));
  when(() => repo.resendSignupCode(any())).thenAnswer((_) async {});
  when(() => repo.verifySignupCode(email: any(named: 'email'), code: any(named: 'code')))
      .thenAnswer((_) async => AuthResponse(user: _user));
  arrange?.call(repo);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => EmailConfirmationScreen(email: _email, verifyOnly: verifyOnly),
      ),
      GoRoute(
        path: '/role',
        builder: (_, state) => Scaffold(
          body: Text('ROLE email=${state.uri.queryParameters['email']} id=${state.uri.queryParameters['id']}'),
        ),
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
  await tester.pump();
  return repo;
}

Future<void> _signUp(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'secret-pass');
  await tester.enterText(fields.at(1), 'secret-pass');
  await tester.tap(find.text('Sign Up'));
  await tester.pump();
  await tester.pump();
}

Future<void> _enterCode(WidgetTester tester, String code) async {
  await tester.enterText(find.descendant(of: find.byType(EmailCodeEntry), matching: find.byType(EditableText)), code);
  await tester.pump();
  await tester.pump();
}

void main() {
  group('AuthErrorMessages', () {
    test('wrong / expired code', () {
      expect(
        AuthErrorMessages.forVerification(const AuthException('Token has expired or is invalid', code: 'otp_expired')),
        AuthErrorMessages.invalidCode,
      );
      expect(
        AuthErrorMessages.forVerification(const AuthException('Invalid token')),
        AuthErrorMessages.invalidCode,
      );
    });

    test('rate limit and offline', () {
      expect(
        AuthErrorMessages.forSending(const AuthException('slow down', statusCode: '429', code: 'over_email_send_rate_limit')),
        AuthErrorMessages.rateLimited,
      );
      expect(AuthErrorMessages.forVerification(const SocketException('x')), AuthErrorMessages.offline);
      expect(AuthErrorMessages.forVerification(StateError('x')), AuthErrorMessages.generic);
    });
  });

  group('EmailConfirmationScreen (code flow)', () {
    testWidgets('sign-up emails a code and switches to code entry', (tester) async {
      final repo = await _pump(tester);
      expect(find.byType(EmailCodeEntry), findsNothing);

      await _signUp(tester);

      verify(() => repo.signUp(email: _email, password: 'secret-pass')).called(1);
      expect(find.byType(EmailCodeEntry), findsOneWidget);
      expect(find.textContaining('${AppConfig.emailOtpLength}-digit code'), findsOneWidget);
      expect(find.textContaining('confirmation link'), findsNothing);
      // Cooldown starts immediately so a code cannot be spammed.
      expect(find.textContaining('Resend code in'), findsOneWidget);
      await tester.pump(AppConfig.otpResendCooldown);
    });

    testWidgets('a wrong code shows an error and clears the input', (tester) async {
      final repo = await _pump(tester, arrange: (r) {
        when(() => r.verifySignupCode(email: any(named: 'email'), code: any(named: 'code')))
            .thenThrow(const AuthException('Token has expired or is invalid', statusCode: '403', code: 'otp_expired'));
      });
      await _signUp(tester);

      await _enterCode(tester, _code);

      verify(() => repo.verifySignupCode(email: _email, code: _code)).called(1);
      expect(find.byKey(const Key('code_error')), findsOneWidget);
      expect(find.text(AuthErrorMessages.invalidCode), findsOneWidget);
      expect(find.byType(EmailCodeEntry), findsOneWidget, reason: 'stays on the code screen');
      final input = tester.widget<EditableText>(
        find.descendant(of: find.byType(EmailCodeEntry), matching: find.byType(EditableText)),
      );
      expect(input.controller.text, isEmpty);
      await tester.pump(AppConfig.otpResendCooldown);
    });

    testWidgets('the right code verifies once and continues to role selection', (tester) async {
      final repo = await _pump(tester);
      await _signUp(tester);

      await _enterCode(tester, _code);
      await tester.pumpAndSettle(AppConfig.otpResendCooldown);

      verify(() => repo.verifySignupCode(email: _email, code: _code)).called(1);
      expect(find.textContaining('ROLE email=$_email id=user-1'), findsOneWidget);
    });

    testWidgets('resend is locked during the cooldown, then emails a new code', (tester) async {
      final repo = await _pump(tester);
      await _signUp(tester);

      await tester.tap(find.textContaining('Resend code in'));
      await tester.pump();
      verifyNever(() => repo.resendSignupCode(any()));

      await tester.pump(AppConfig.otpResendCooldown);
      await tester.pump();
      expect(find.text("Didn't get it? Resend code"), findsOneWidget);

      await tester.tap(find.text("Didn't get it? Resend code"));
      await tester.pump();
      await tester.pump();

      verify(() => repo.resendSignupCode(_email)).called(1);
      expect(find.textContaining('Resend code in'), findsOneWidget, reason: 'cooldown restarts');
      await tester.pump(AppConfig.otpResendCooldown);
    });

    testWidgets('a rate-limited resend explains itself and restarts the cooldown', (tester) async {
      final repo = await _pump(tester, arrange: (r) {
        when(() => r.resendSignupCode(any())).thenThrow(
          const AuthException('rate limit', statusCode: '429', code: 'over_email_send_rate_limit'),
        );
      });
      await _signUp(tester);
      await tester.pump(AppConfig.otpResendCooldown);
      await tester.pump();

      await tester.tap(find.text("Didn't get it? Resend code"));
      await tester.pump();
      await tester.pump();

      verify(() => repo.resendSignupCode(_email)).called(1);
      expect(find.text(AuthErrorMessages.rateLimited), findsOneWidget);
      expect(find.textContaining('Resend code in'), findsOneWidget);
      await tester.pump(AppConfig.otpResendCooldown);
    });

    testWidgets('unconfirmed account: skips the password step and sends a code', (tester) async {
      final repo = await _pump(tester, verifyOnly: true);
      await tester.pump();
      await tester.pump();

      verify(() => repo.resendSignupCode(_email)).called(1);
      verifyNever(() => repo.signUp(email: any(named: 'email'), password: any(named: 'password')));
      expect(find.byType(EmailCodeEntry), findsOneWidget);
      expect(find.text('Set your password'), findsNothing);
      await tester.pump(AppConfig.otpResendCooldown);
    });
  });
}
