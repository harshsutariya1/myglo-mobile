import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/app_config.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/phone_numbers.dart';
import '../../../../../core/widgets/snackbar_utils.dart';
import '../../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../../shared/authentication/models/auth_error_messages.dart';
import '../../../../shared/authentication/models/auth_repository.dart';
import '../../../../shared/authentication/models/profile_model.dart';
import '../../../../shared/authentication/views/widgets/email_code_entry.dart';

/// Verifies the provider's mobile number in two steps: enter the number,
/// then the code texted to it.
///
/// Supabase Auth sends and checks the code; once it's accepted the server
/// copies the number onto the profile and marks it verified
/// (`confirm_phone_verification`). Changing the number later, here or in the
/// profile editor, means verifying the new one.
class VerifyPhoneScreen extends ConsumerStatefulWidget {
  const VerifyPhoneScreen({super.key});

  @override
  ConsumerState<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

enum _Stage { number, code }

class _VerifyPhoneScreenState extends ConsumerState<VerifyPhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();

  Timer? _cooldownTimer;
  int _resendSecondsLeft = 0;
  _Stage _stage = _Stage.number;
  bool _prefilled = false;
  bool _isSending = false;
  bool _isVerifying = false;

  /// Auth accepted the code but saving it to the profile failed: "Continue"
  /// retries only the saving, as the code can't be used twice.
  bool _codeAccepted = false;
  String? _codeError;

  /// The number the code was texted to (E.164).
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _phoneController.dispose();
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

  static String? _validate(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Enter your mobile number';
    if (PhoneNumbers.toE164(value) == null) {
      return 'Enter a mobile number, e.g. 0412 345 678. Include the country code (+…) outside Australia';
    }
    return null;
  }

  Future<void> _sendCode() async {
    if (_isSending || !_formKey.currentState!.validate()) return;
    final phone = PhoneNumbers.toE164(_phoneController.text)!;

    FocusScope.of(context).unfocus();
    setState(() => _isSending = true);
    try {
      final started = await ref.read(authRepositoryProvider).startPhoneVerification(phone);
      if (!mounted) return;
      _phone = phone;
      if (started == PhoneVerificationStart.alreadyConfirmed) {
        await _finish();
        return;
      }
      _pinController.clear();
      setState(() {
        _stage = _Stage.code;
        _codeAccepted = false;
        _codeError = null;
      });
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      if (e is AuthException && (e.statusCode == '429' || e.code == 'over_sms_send_rate_limit')) {
        _startCooldown();
      }
      context.showAppSnackBar(AuthErrorMessages.forPhoneCodeRequest(e), isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _resendCode() async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
      _codeError = null;
    });
    try {
      await ref.read(authRepositoryProvider).resendPhoneCode(_phone);
      if (!mounted) return;
      _pinController.clear();
      _startCooldown();
      context.showAppSnackBar('A new code is on its way.');
    } catch (e) {
      if (!mounted) return;
      if (e is AuthException && (e.statusCode == '429' || e.code == 'over_sms_send_rate_limit')) {
        _startCooldown();
      }
      context.showAppSnackBar(AuthErrorMessages.forPhoneCodeRequest(e), isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verify([String? completed]) async {
    if (_isVerifying) return;
    if (_codeAccepted) return _finish();
    final code = (completed ?? _pinController.text).trim();
    if (code.length != AppConfig.smsOtpLength) return;

    setState(() {
      _isVerifying = true;
      _codeError = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyPhoneCode(phone: _phone, code: code);
    } catch (e) {
      if (!mounted) return;
      _pinController.clear();
      setState(() {
        _isVerifying = false;
        _codeError = AuthErrorMessages.forVerification(e);
      });
      return;
    }
    if (!mounted) return;
    _codeAccepted = true;
    await _finish();
  }

  /// Saves the number Auth confirmed to the profile and leaves.
  Future<void> _finish() async {
    setState(() {
      _isVerifying = true;
      _codeError = null;
    });
    try {
      await ref.read(authRepositoryProvider).confirmPhoneVerification();
      if (!mounted) return;
      ref.invalidate(userProfileProvider);
      HapticFeedback.mediumImpact();
      context.showAppSnackBar('Your phone number is verified.');
      if (context.canPop()) context.pop();
    } catch (e) {
      if (!mounted) return;
      // The code was right; only saving it failed. Stay on the code step
      // (or move to it) so "Continue" can try the saving again.
      setState(() {
        _stage = _Stage.code;
        _codeAccepted = true;
        _codeError = "Your code was right, but we couldn't save your number. Tap Continue to try again.";
      });
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _changeNumber() {
    _cooldownTimer?.cancel();
    _pinController.clear();
    setState(() {
      _stage = _Stage.number;
      _codeAccepted = false;
      _codeError = null;
      _resendSecondsLeft = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value?.profile;
    if (!_prefilled && profile != null) {
      _prefilled = true;
      final saved = profile.phoneNumber?.trim() ?? '';
      if (saved.isNotEmpty && _phoneController.text.isEmpty) _phoneController.text = PhoneNumbers.display(saved);
    }
    final verified = profile?.isPhoneVerified ?? false;
    // The number in the field is the one already verified: nothing to do.
    final unchanged = verified && PhoneNumbers.same(_phoneController.text, profile?.phoneNumber);
    final onCode = _stage == _Stage.code;

    return Scaffold(
      appBar: AppBar(title: Text(onCode ? 'Enter your code' : 'Phone number')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (onCode) ...[
                      EmailCodeEntry(
                        email: PhoneNumbers.display(_phone),
                        pinController: _pinController,
                        onCompleted: _verify,
                        onResend: _resendCode,
                        resendSecondsLeft: _resendSecondsLeft,
                        errorText: _codeError,
                        enabled: !_isVerifying && !_codeAccepted,
                        isResending: _isSending,
                        purpose: 'Enter it below to verify your number.',
                        icon: Icons.phone_outlined,
                        length: AppConfig.smsOtpLength,
                      ),
                      Center(
                        child: TextButton(
                          onPressed: _isVerifying ? null : _changeNumber,
                          child: const Text('Use a different number'),
                        ),
                      ),
                    ] else
                      _NumberStep(
                        controller: _phoneController,
                        validator: _validate,
                        enabled: !_isSending,
                        verified: unchanged,
                        hadVerifiedNumber: verified,
                        onSubmitted: unchanged ? null : _sendCode,
                      ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: onCode
                          ? (_isVerifying ? null : _verify)
                          : (_isSending || unchanged ? null : _sendCode),
                      child: (onCode ? _isVerifying : _isSending)
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(onCode ? 'Continue' : (unchanged ? 'Verified' : 'Text me a code')),
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

/// First step: the number, and what verifying it is for.
class _NumberStep extends StatelessWidget {
  const _NumberStep({
    required this.controller,
    required this.validator,
    required this.enabled,
    required this.verified,
    required this.hadVerifiedNumber,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final bool enabled;

  /// The number in the field is verified.
  final bool verified;

  /// The profile has a verified number (maybe not the one in the field).
  final bool hadVerifiedNumber;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final String explanation;
    if (verified) {
      explanation = 'This number is verified. To change it, enter the new number and verify it.';
    } else if (hadVerifiedNumber) {
      explanation = "We'll text a ${AppConfig.smsOtpLength}-digit code to the new number. "
          'Your current number stays verified until the new one is confirmed.';
    } else {
      explanation = "We'll text you a ${AppConfig.smsOtpLength}-digit code to confirm the number is yours.";
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          verified ? Icons.verified_user_outlined : Icons.phone_outlined,
          size: 80,
          color: verified ? AppTheme.success : scheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          verified ? 'Phone number verified' : 'Verify your phone number',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: scheme.onSurface),
        ),
        const SizedBox(height: 12),
        Text(explanation, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.4)),
        const SizedBox(height: 28),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d+\s()\-.]')),
            LengthLimitingTextInputFormatter(20),
          ],
          decoration: InputDecoration(
            labelText: 'Mobile number',
            hintText: '0412 345 678',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: validator,
          onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
        ),
        const SizedBox(height: 10),
        Text(
          'Standard message rates may apply. Clients see this number on your profile.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}
