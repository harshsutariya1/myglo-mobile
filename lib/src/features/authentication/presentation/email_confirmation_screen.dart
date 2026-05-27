import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../data/auth_repository.dart';

class EmailConfirmationScreen extends ConsumerStatefulWidget {
  final String email;

  const EmailConfirmationScreen({super.key, required this.email});

  @override
  ConsumerState<EmailConfirmationScreen> createState() =>
      _EmailConfirmationScreenState();
}

class _EmailConfirmationScreenState
    extends ConsumerState<EmailConfirmationScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (password.isEmpty || confirm.isEmpty) return;

    if (password.length < 6) {
      developer.log(
        'Password validation failed: minimum length requirement not met.',
        name: 'EmailConfirmationScreen',
      );
      context.showAppSnackBar(
        'Password must be at least 6 characters',
        isError: true,
      );
      return;
    }

    if (password != confirm) {
      developer.log(
        'Password validation failed: passwords do not match.',
        name: 'EmailConfirmationScreen',
      );
      context.showAppSnackBar('Passwords do not match', isError: true);
      return;
    }

    developer.log(
      'Starting sign up process for email: ${widget.email}',
      name: 'EmailConfirmationScreen',
    );
    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      developer.log(
        'Calling supabase.auth.signUp...',
        name: 'EmailConfirmationScreen',
      );
      await supabase.auth.signUp(email: widget.email, password: password);

      developer.log(
        'Sign up successful, awaiting email confirmation.',
        name: 'EmailConfirmationScreen',
      );
      if (mounted) {
        setState(() {
          _emailSent = true;
          _isLoading = false;
        });
      }
    } on AuthException catch (e) {
      developer.log(
        'Supabase AuthException during sign up: ${e.message}',
        level: 900,
        name: 'EmailConfirmationScreen',
      );
      if (mounted) context.showAppSnackBar(e.message, isError: true);
    } catch (e) {
      developer.log(
        'Unexpected exception during sign up: $e',
        level: 1000,
        name: 'EmailConfirmationScreen',
      );
      if (mounted) context.showAppSnackBar(e.toString(), isError: true);
    } finally {
      developer.log(
        'Sign up process completed',
        name: 'EmailConfirmationScreen',
      );
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkConfirmation() async {
    developer.log(
      'Starting confirmation check via sign in attempt...',
      name: 'EmailConfirmationScreen',
    );
    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseClientProvider);

      // Attempt login to check if confirmed
      developer.log(
        'Attempting sign in with password to verify email confirmation',
        name: 'EmailConfirmationScreen',
      );
      final response = await supabase.auth.signInWithPassword(
        email: widget.email,
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        developer.log(
          'Sign in successful. Email properly confirmed. Navigating to /role',
          name: 'EmailConfirmationScreen',
        );
        if (mounted) {
          context.showAppSnackBar('Account confirmed successfully!');
          context.go('/role');
        }
      } else {
        developer.log(
          'Sign in returned null user. Email likely unconfirmed.',
          name: 'EmailConfirmationScreen',
        );
        _showUnconfirmedPopup();
      }
    } on AuthException catch (e) {
      if (e.message.contains('Email not confirmed')) {
        developer.log(
          'Intercepted expected exception: ${e.message}',
          name: 'EmailConfirmationScreen',
        );
        _showUnconfirmedPopup();
      } else {
        developer.log(
          'Unexpected AuthException during confirmation check: ${e.message}',
          level: 900,
          name: 'EmailConfirmationScreen',
        );
        if (mounted) context.showAppSnackBar(e.message, isError: true);
      }
    } catch (e) {
      developer.log(
        'Unexpected exception during confirmation check: $e',
        level: 1000,
        name: 'EmailConfirmationScreen',
      );
      if (mounted) context.showAppSnackBar(e.toString(), isError: true);
    } finally {
      developer.log(
        'Confirmation check completed',
        name: 'EmailConfirmationScreen',
      );
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showUnconfirmedPopup() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Email Not Confirmed'),
        content: const Text(
          'Please check your inbox and click the confirmation link before continuing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: AppTheme.burntOrange),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_emailSent ? 'Confirm Email' : 'Create Password'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_emailSent) ...[
                const Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: AppTheme.primaryPink,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Set your password',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkRed,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Creating account for \n${widget.email}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  obscureText: true,
                ),
              ] else ...[
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
                  'We\'ve sent a confirmation link to \n${widget.email}.\nPlease click the link to verify your account.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_emailSent ? _checkConfirmation : _signUp),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_emailSent ? 'Continue' : 'Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
