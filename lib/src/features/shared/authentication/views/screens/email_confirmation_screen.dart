import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/config/app_config.dart';
import '../../../../../core/routing/app_router.dart';
import '../../../../../core/utils/app_logger.dart';
import '../../../../../core/widgets/snackbar_utils.dart';
import '../../controllers/email_confirmation_controller.dart';
import '../../models/auth_error_messages.dart';
import '../widgets/email_code_entry.dart';
import '../widgets/password_setup_form.dart';

/// Creates an account in two steps: choose a password, then enter the code
/// emailed to the user.
///
/// With [verifyOnly] the password step is skipped and a fresh code is sent
/// straight away. That is the path for someone whose account exists but was
/// never confirmed (e.g. they closed the app before entering the code).
class EmailConfirmationScreen extends ConsumerStatefulWidget {
  final String email;
  final bool verifyOnly;

  const EmailConfirmationScreen({
    super.key,
    required this.email,
    this.verifyOnly = false,
  });

  @override
  ConsumerState<EmailConfirmationScreen> createState() =>
      _EmailConfirmationScreenState();
}

class _EmailConfirmationScreenState
    extends ConsumerState<EmailConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController(text: '123456'); //default password during development only
  final _confirmPasswordController = TextEditingController(text: '123456'); //default password during development only
  final _pinController = TextEditingController();

  Timer? _cooldownTimer;
  int _resendSecondsLeft = 0;
  bool _codeStage = false;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _codeError;

  @override
  void initState() {
    super.initState();
    if (widget.verifyOnly) {
      _codeStage = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pinController.dispose();
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

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(emailConfirmationControllerProvider.notifier);
    await controller.signUp(
      email: widget.email,
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;
    final state = ref.read(emailConfirmationControllerProvider);
    if (state.hasError) {
      context.showAppSnackBar(
        AuthErrorMessages.forSending(state.error!),
        isError: true,
      );
      return;
    }
    setState(() => _codeStage = true);
    _startCooldown();
  }

  /// Emails a code: used on entry for [EmailConfirmationScreen.verifyOnly] and
  /// by the "resend" button.
  Future<void> _sendCode() async {
    if (_isResending) return;
    setState(() {
      _isResending = true;
      _codeError = null;
    });
    try {
      await ref
          .read(emailConfirmationControllerProvider.notifier)
          .resendCode(widget.email);
      if (!mounted) return;
      _pinController.clear();
      _startCooldown();
      context.showAppSnackBar('A new code is on its way.');
    } catch (e, st) {
      AppLogger.w('EmailConfirmationScreen: resend failed: $e', tag: 'EmailConfirmation');
      if (e is! AuthException) {
        AppLogger.e('EmailConfirmationScreen: unexpected resend error', tag: 'EmailConfirmation', error: e, stackTrace: st);
      }
      if (!mounted) return;
      // Supabase refuses a second email within the cooldown; reflect that in the UI.
      if (e is AuthException &&
          (e.statusCode == '429' || e.code == 'over_email_send_rate_limit')) {
        _startCooldown();
      }
      context.showAppSnackBar(AuthErrorMessages.forSending(e), isError: true);
    } finally {
      if (mounted) setState(() => _isResending = false);
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
      final response = await ref
          .read(emailConfirmationControllerProvider.notifier)
          .verifyCode(email: widget.email, code: code);
      final user = response.user;
      if (user == null || !mounted) return;

      context.showAppSnackBar('Email verified!');
      // The auth-state listener also redirects; going explicitly keeps this
      // screen from lingering if that event is delayed.
      context.go(
        Uri(
          path: AppRoute.roleSelection.path,
          queryParameters: {'email': user.email ?? widget.email, 'id': user.id},
        ).toString(),
      );
    } catch (e, st) {
      if (e is! AuthException) {
        AppLogger.e('EmailConfirmationScreen: unexpected verify error', tag: 'EmailConfirmation', error: e, stackTrace: st);
      }
      if (!mounted) return;
      _pinController.clear();
      setState(() => _codeError = AuthErrorMessages.forVerification(e));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signUpLoading = ref.watch(emailConfirmationControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(_codeStage ? 'Verify Email' : 'Create Password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_codeStage)
                      PasswordSetupForm(
                        email: widget.email,
                        passwordController: _passwordController,
                        confirmPasswordController: _confirmPasswordController,
                      )
                    else
                      EmailCodeEntry(
                        email: widget.email,
                        pinController: _pinController,
                        onCompleted: _verify,
                        onResend: _sendCode,
                        resendSecondsLeft: _resendSecondsLeft,
                        errorText: _codeError,
                        enabled: !_isVerifying,
                        isResending: _isResending,
                      ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _codeStage
                          ? (_isVerifying ? null : _verify)
                          : (signUpLoading ? null : _signUp),
                      child: (_codeStage ? _isVerifying : signUpLoading)
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_codeStage ? 'Verify' : 'Sign Up'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
