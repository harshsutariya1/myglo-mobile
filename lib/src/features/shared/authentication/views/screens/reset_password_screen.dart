import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/app_config.dart';
import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/app_logger.dart';
import '../../../../../core/widgets/snackbar_utils.dart';
import '../../models/auth_error_messages.dart';
import '../../models/auth_repository.dart';
import '../widgets/email_code_entry.dart';
import '../widgets/password_setup_form.dart';

/// Sets a new password in two steps: enter the code emailed to [email], then
/// choose the password.
///
/// Used for a forgotten password (from sign-in, signed out) and for "Change
/// password" in settings (signed in). The code is sent as the screen opens.
/// Entering it signs the user in, which is what allows the password to be
/// changed; the router guard keeps this screen up until that's done. Someone
/// who leaves after the code but before choosing a password stays signed in
/// (they proved the inbox is theirs) with their old password unchanged.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

enum _Stage { code, password }

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  static const _tag = 'ResetPassword';

  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  /// Opened from settings by someone already signed in: go back there
  /// afterwards instead of into the app from the start.
  late final bool _startedSignedIn;

  Timer? _cooldownTimer;
  int _resendSecondsLeft = 0;
  _Stage _stage = _Stage.code;
  bool _isSending = false;
  bool _isVerifying = false;
  bool _isSaving = false;
  String? _codeError;

  String get _email => widget.email.trim();

  @override
  void initState() {
    super.initState();
    _startedSignedIn = ref.read(authRepositoryProvider).currentUser != null;
    if (_email.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode(announce: false));
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _pinController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendSecondsLeft = AppConfig.otpResendCooldown.inSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendSecondsLeft--);
      if (_resendSecondsLeft <= 0) timer.cancel();
    });
  }

  /// Emails a code: as the screen opens, and from the "resend" button.
  Future<void> _sendCode({bool announce = true}) async {
    if (_isSending || !mounted) return;
    setState(() {
      _isSending = true;
      _codeError = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetCode(_email);
      if (!mounted) return;
      _pinController.clear();
      _startCooldown();
      if (announce) context.showAppSnackBar('A new code is on its way.');
    } catch (e) {
      if (!mounted) return;
      // Supabase refuses a second email within the cooldown; reflect that in the UI.
      if (e is AuthException && (e.statusCode == '429' || e.code == 'over_email_send_rate_limit')) {
        _startCooldown();
      }
      context.showAppSnackBar(AuthErrorMessages.forSending(e), isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verify([String? completed]) async {
    final code = (completed ?? _pinController.text).trim();
    if (code.length != AppConfig.emailOtpLength || _isVerifying) return;

    setState(() {
      _isVerifying = true;
      _codeError = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyPasswordResetCode(email: _email, code: code);
      if (!mounted) return;
      _cooldownTimer?.cancel();
      setState(() => _stage = _Stage.password);
    } catch (e) {
      if (!mounted) return;
      _pinController.clear();
      setState(() => _codeError = AuthErrorMessages.forVerification(e));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _savePassword() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(_passwordController.text.trim());
      // Lets the device's password manager offer to save the new password.
      TextInput.finishAutofillContext();
      if (!mounted) return;
      AppLogger.i('Password changed', tag: _tag);
      context.showAppSnackBar('Your password has been changed.');
      if (_startedSignedIn && context.canPop()) {
        context.pop();
      } else {
        // The router guard sends a signed-in user to the right home / onboarding screen.
        context.go(AppRoute.splash.path);
      }
    } catch (e) {
      if (!mounted) return;
      if (AuthErrorMessages.needsNewCode(e)) {
        // The session from the code is gone: start again from a fresh code.
        _passwordController.clear();
        _confirmPasswordController.clear();
        _pinController.clear();
        setState(() {
          _stage = _Stage.code;
          _codeError = AuthErrorMessages.sessionExpired;
        });
      } else {
        context.showAppSnackBar(AuthErrorMessages.forPasswordUpdate(e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onCode = _stage == _Stage.code;
    final busy = onCode ? _isVerifying : _isSaving;

    return Scaffold(
      appBar: AppBar(title: Text(onCode ? 'Check your email' : 'New password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _email.isEmpty
                  ? const _MissingEmail()
                  : AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (onCode)
                              EmailCodeEntry(
                                email: _email,
                                pinController: _pinController,
                                onCompleted: _verify,
                                onResend: _sendCode,
                                resendSecondsLeft: _resendSecondsLeft,
                                errorText: _codeError,
                                enabled: !_isVerifying,
                                isResending: _isSending,
                                purpose: 'Enter it below to choose a new password.',
                              )
                            else
                              PasswordSetupForm(
                                email: _email,
                                passwordController: _passwordController,
                                confirmPasswordController: _confirmPasswordController,
                                title: 'Choose a new password',
                                subtitle: 'For $_email.\nYour other devices will be signed out.',
                                passwordLabel: 'New password',
                                enabled: !_isSaving,
                              ),
                            const SizedBox(height: 32),
                            ElevatedButton(
                              onPressed: busy ? null : (onCode ? _verify : _savePassword),
                              child: busy
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(onCode ? 'Continue' : 'Save password'),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The screen was opened without an address to send the code to.
class _MissingEmail extends StatelessWidget {
  const _MissingEmail();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.lock_outline, size: 80, color: scheme.primary),
        const SizedBox(height: 24),
        Text(
          "We don't know which account this is for",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: scheme.onSurface),
        ),
        const SizedBox(height: 12),
        const Text(
          'Go back, enter your email address and choose "Forgot password?" again.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}
