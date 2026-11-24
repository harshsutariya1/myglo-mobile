import 'package:flutter/material.dart';
import '../../../../../core/config/app_config.dart';
import '../../../../../core/theme/app_theme.dart';

class PasswordSetupForm extends StatefulWidget {
  final String email;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;

  const PasswordSetupForm({
    super.key,
    required this.email,
    required this.passwordController,
    required this.confirmPasswordController,
    this.title = 'Set your password',
    this.subtitle,
    this.passwordLabel = 'Password',
    this.enabled = true,
  });

  final String title;

  /// Defaults to "Creating account for" followed by the email address.
  final String? subtitle;
  final String passwordLabel;
  final bool enabled;

  @override
  State<PasswordSetupForm> createState() => _PasswordSetupFormState();
}

class _PasswordSetupFormState extends State<PasswordSetupForm> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.lock_outline, size: 80, color: context.colorScheme.primary),
        SizedBox(height: 24),
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: context.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.subtitle ?? 'Creating account for \n${widget.email}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.black54),
        ),
        const SizedBox(height: 32),
        TextFormField(
          controller: widget.passwordController,
          enabled: widget.enabled,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: widget.passwordLabel,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
          obscureText: _obscurePassword,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Password is required';
            }
            if (value.trim().length < AppConfig.passwordMinLength) {
              return 'Password must be at least ${AppConfig.passwordMinLength} characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: widget.confirmPasswordController,
          enabled: widget.enabled,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          obscureText: true,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please confirm your password';
            }
            if (value.trim() != widget.passwordController.text.trim()) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
      ],
    );
  }
}
