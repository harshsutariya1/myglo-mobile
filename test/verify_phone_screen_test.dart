import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myglo/src/core/config/app_config.dart';
import 'package:myglo/src/core/config/remote_app_config.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/providers/provider_profiles/views/screens/verify_phone_screen.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/auth_error_messages.dart';
import 'package:myglo/src/features/shared/authentication/models/auth_repository.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:myglo/src/features/shared/authentication/views/widgets/email_code_entry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

const _number = '+61412345678';
final _code = '4' * AppConfig.smsOtpLength;

final _user = User(
  id: 'prov-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  email: 'mia@example.com',
  createdAt: DateTime(2026).toIso8601String(),
);

const _profile = ProfileModel(id: 'prov-1', role: UserRole.provider, providerName: 'Glow Studio');

/// Opens the screen the way settings does (pushed), with a profile that is
/// re-read after each change like the real provider.
Future<_MockAuthRepository> _pump(
  WidgetTester tester, {
  ProfileModel profile = _profile,
  bool required = false,
  void Function(_MockAuthRepository repo)? arrange,
}) async {
  final repo = _MockAuthRepository();
  when(() => repo.startPhoneVerification(any())).thenAnswer((_) async => PhoneVerificationStart.codeSent);
  when(() => repo.resendPhoneCode(any())).thenAnswer((_) async {});
  when(() => repo.verifyPhoneCode(phone: any(named: 'phone'), code: any(named: 'code'))).thenAnswer((_) async {});
  when(() => repo.confirmPhoneVerification()).thenAnswer((_) async {});
  arrange?.call(repo);

  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, _) => Scaffold(
          body: TextButton(onPressed: () => context.push('/verify'), child: const Text('open')),
        ),
      ),
      GoRoute(path: '/verify', builder: (_, _) => const VerifyPhoneScreen()),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        userProfileProvider.overrideWith(
          (ref) async => AppUserProfile(rawUser: _user, role: UserRole.provider, profile: profile),
        ),
        remoteAppConfigProvider.overrideWith(
          (ref) async => RemoteAppConfig(requireProviderPhoneVerification: required),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('open'));
  await _settle(tester);
  return repo;
}

/// Text cursors and the resend countdown never stop, so frames are pumped
/// for a fixed time instead of until idle.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _requestCode(WidgetTester tester, String number) async {
  await tester.enterText(find.byType(TextFormField), number);
  await tester.pump();
  await tester.tap(find.text('Text me a code'));
  await _settle(tester);
}

Future<void> _enterCode(WidgetTester tester, String code) async {
  await tester.enterText(find.descendant(of: find.byType(EmailCodeEntry), matching: find.byType(EditableText)), code);
  await _settle(tester);
}

void main() {
  group('AuthErrorMessages.forPhoneCodeRequest', () {
    test('explains refusals the provider can fix', () {
      expect(
        AuthErrorMessages.forPhoneCodeRequest(const AuthException('taken', code: 'phone_exists')),
        AuthErrorMessages.phoneTaken,
      );
      expect(
        AuthErrorMessages.forPhoneCodeRequest(const AuthException('bad', code: 'validation_failed')),
        AuthErrorMessages.phoneInvalid,
      );
      expect(
        AuthErrorMessages.forPhoneCodeRequest(const AuthException('slow', statusCode: '429', code: 'over_sms_send_rate_limit')),
        AuthErrorMessages.smsRateLimited,
      );
    });

    test('never shows raw server text', () {
      expect(
        AuthErrorMessages.forPhoneCodeRequest(const AuthException('twilio: 21608 unverified', code: 'sms_send_failed')),
        AuthErrorMessages.smsFailed,
      );
      expect(
        AuthErrorMessages.forPhoneCodeRequest(const AuthException('Unsupported phone provider', code: 'phone_provider_disabled')),
        AuthErrorMessages.smsUnavailable,
      );
      expect(AuthErrorMessages.forPhoneCodeRequest(const AuthException('pq: internal')), AuthErrorMessages.generic);
      expect(AuthErrorMessages.forPhoneCodeRequest(const SocketException('x')), AuthErrorMessages.offline);
    });
  });

  group('VerifyPhoneScreen', () {
    testWidgets('starts from the number on the profile', (tester) async {
      final repo = await _pump(tester, profile: _profile.copyWith(phoneNumber: '0412345678'));

      expect(find.text('Verify your phone number'), findsOneWidget);
      expect(tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text, '0412 345 678');
      verifyNever(() => repo.startPhoneVerification(any()));
    });

    testWidgets('says when verification is required to be listed', (tester) async {
      await _pump(tester, required: true);

      expect(find.textContaining("Clients can't find or book you on Myglo until your number is verified."), findsOneWidget);
    });

    testWidgets('a number that cannot be texted is not sent', (tester) async {
      final repo = await _pump(tester);

      await _requestCode(tester, '07 5555 1234');

      expect(find.textContaining('Enter a mobile number'), findsOneWidget);
      verifyNever(() => repo.startPhoneVerification(any()));
    });

    testWidgets('number, code, verified: saved by the server and back to settings', (tester) async {
      final repo = await _pump(tester);

      await _requestCode(tester, '0412 345 678');
      verify(() => repo.startPhoneVerification(_number)).called(1);
      expect(find.byType(EmailCodeEntry), findsOneWidget);
      expect(find.textContaining('0412 345 678'), findsOneWidget);
      expect(find.textContaining('Enter it below to verify your number.'), findsOneWidget);

      await _enterCode(tester, _code);

      verifyInOrder([
        () => repo.verifyPhoneCode(phone: _number, code: _code),
        () => repo.confirmPhoneVerification(),
      ]);
      expect(find.text('open'), findsOneWidget);
      expect(find.text('Your phone number is verified.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a wrong code is explained and nothing is saved', (tester) async {
      final repo = await _pump(
        tester,
        arrange: (repo) => when(() => repo.verifyPhoneCode(phone: any(named: 'phone'), code: any(named: 'code')))
            .thenThrow(const AuthException('Token has expired or is invalid', code: 'otp_expired')),
      );

      await _requestCode(tester, '0412 345 678');
      await _enterCode(tester, _code);

      expect(find.text(AuthErrorMessages.invalidCode), findsOneWidget);
      expect(find.byType(EmailCodeEntry), findsOneWidget);
      verifyNever(() => repo.confirmPhoneVerification());
    });

    testWidgets('a number used by another account is refused with the reason', (tester) async {
      await _pump(
        tester,
        arrange: (repo) => when(() => repo.startPhoneVerification(any()))
            .thenThrow(const AuthException('A user with this phone number has already been registered', code: 'phone_exists')),
      );

      await _requestCode(tester, '0412 345 678');

      expect(find.text(AuthErrorMessages.phoneTaken), findsOneWidget);
      expect(find.byType(EmailCodeEntry), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('if saving fails after a right code, Continue retries the saving only', (tester) async {
      var attempts = 0;
      final repo = await _pump(
        tester,
        arrange: (repo) => when(() => repo.confirmPhoneVerification()).thenAnswer((_) async {
          if (++attempts == 1) throw const SocketException('offline');
        }),
      );

      await _requestCode(tester, '0412 345 678');
      await _enterCode(tester, _code);

      expect(find.textContaining("Your code was right, but we couldn't save your number."), findsOneWidget);

      await tester.ensureVisible(find.text('Continue'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await _settle(tester);

      verify(() => repo.verifyPhoneCode(phone: _number, code: _code)).called(1);
      verify(() => repo.confirmPhoneVerification()).called(2);
      expect(find.text('open'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a number Auth already confirmed is saved without another text', (tester) async {
      final repo = await _pump(
        tester,
        arrange: (repo) => when(() => repo.startPhoneVerification(any()))
            .thenAnswer((_) async => PhoneVerificationStart.alreadyConfirmed),
      );

      await _requestCode(tester, '0412 345 678');

      verify(() => repo.confirmPhoneVerification()).called(1);
      verifyNever(() => repo.verifyPhoneCode(phone: any(named: 'phone'), code: any(named: 'code')));
      expect(find.text('open'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a verified number has nothing to do until it is changed', (tester) async {
      final repo = await _pump(
        tester,
        profile: _profile.copyWith(phoneNumber: _number, phoneVerifiedAt: DateTime(2026, 11, 1)),
      );

      expect(find.text('Phone number verified'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Verified')).onPressed, isNull);

      await tester.enterText(find.byType(TextFormField), '0499 000 111');
      await tester.pump();
      expect(find.textContaining('Your current number stays verified until the new one is confirmed.'), findsOneWidget);
      await tester.tap(find.text('Text me a code'));
      await _settle(tester);

      verify(() => repo.startPhoneVerification('+61499000111')).called(1);
    });

    testWidgets('the code can be sent again once the wait is over, or the number changed', (tester) async {
      final repo = await _pump(tester);
      await _requestCode(tester, '0412 345 678');
      expect(find.textContaining('Resend code in'), findsOneWidget);

      await tester.pump(AppConfig.otpResendCooldown + const Duration(seconds: 1));
      await tester.tap(find.text("Didn't get it? Resend code"));
      await _settle(tester);
      verify(() => repo.resendPhoneCode(_number)).called(1);

      await tester.tap(find.text('Use a different number'));
      await _settle(tester);
      expect(find.byType(EmailCodeEntry), findsNothing);
      expect(find.text('Text me a code'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
