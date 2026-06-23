import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class VerifyEmailView extends StatelessWidget {
  final String email;

  const VerifyEmailView({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.mark_email_unread_outlined,
          size: 80,
          color: AppTheme.primaryPink,
        ),
        const SizedBox(height: 24),
        const Text(
          'Verify your email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkRed,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'We\'ve sent a confirmation link to \n$email.\nPlease click the link to verify your account.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}
