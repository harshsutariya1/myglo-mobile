import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';

import '../../../../../core/config/app_config.dart';
import '../../../../../core/theme/app_theme.dart';

/// Code-entry step of account creation: explains where the code was sent, takes
/// the digits, and offers a rate-limited "resend".
class EmailCodeEntry extends StatelessWidget {
  const EmailCodeEntry({
    super.key,
    required this.email,
    required this.pinController,
    required this.onCompleted,
    required this.onResend,
    required this.resendSecondsLeft,
    this.errorText,
    this.enabled = true,
    this.isResending = false,
  });

  final String email;
  final TextEditingController pinController;
  final ValueChanged<String> onCompleted;
  final VoidCallback onResend;

  /// Seconds until another code may be requested; 0 means resend is available.
  final int resendSecondsLeft;
  final String? errorText;
  final bool enabled;
  final bool isResending;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final baseTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: scheme.onSurface,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.25)),
      ),
    );

    final canResend = resendSecondsLeft == 0 && !isResending && enabled;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.mark_email_unread_outlined, size: 80, color: scheme.primary),
        const SizedBox(height: 24),
        Text(
          'Enter your code',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "We've sent a ${AppConfig.emailOtpLength}-digit code to\n$email.\nEnter it below to create your account.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 32),
        Center(
          child: Pinput(
            length: AppConfig.emailOtpLength,
            controller: pinController,
            enabled: enabled,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofillHints: const [AutofillHints.oneTimeCode],
            defaultPinTheme: baseTheme,
            focusedPinTheme: baseTheme.copyWith(
              decoration: baseTheme.decoration!.copyWith(
                border: Border.all(color: scheme.primary, width: 2),
              ),
            ),
            errorPinTheme: baseTheme.copyWith(
              decoration: baseTheme.decoration!.copyWith(
                border: Border.all(color: scheme.secondary, width: 2),
              ),
            ),
            forceErrorState: errorText != null,
            onCompleted: onCompleted,
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            errorText!,
            key: const Key('code_error'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.secondary,
            ),
          ),
        ],
        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: canResend ? onResend : null,
            child: Text(
              isResending
                  ? 'Sending...'
                  : resendSecondsLeft > 0
                  ? 'Resend code in ${resendSecondsLeft}s'
                  : "Didn't get it? Resend code",
              style: TextStyle(
                color: canResend
                    ? scheme.secondary
                    : scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
