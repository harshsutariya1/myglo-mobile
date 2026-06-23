import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../controllers/email_confirmation_controller.dart';
import '../widgets/password_setup_form.dart';
import '../widgets/verify_email_view.dart';

class EmailConfirmationScreen extends ConsumerStatefulWidget {
  final String email;

  const EmailConfirmationScreen({super.key, required this.email});

  @override
  ConsumerState<EmailConfirmationScreen> createState() =>
      _EmailConfirmationScreenState();
}

class _EmailConfirmationScreenState
    extends ConsumerState<EmailConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController(text: "123456");
  final _confirmPasswordController = TextEditingController(text: "123456");

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(emailConfirmationControllerProvider.notifier);
    final password = _passwordController.text.trim();

    await controller.signUp(email: widget.email, password: password);

    final state = ref.read(emailConfirmationControllerProvider);
    if (state.hasError && mounted) {
      context.showAppSnackBar(state.error.toString(), isError: true);
    }
  }

  Future<void> _checkConfirmation() async {
    final controller = ref.read(emailConfirmationControllerProvider.notifier);

    try {
      final response = await controller.checkConfirmation(
        email: widget.email,
        password: _passwordController.text.trim(),
      );

      if (response != null && response.user != null) {
        if (mounted) {
          context.showAppSnackBar('Account confirmed successfully!');
          context.go(
            '/role',
            extra: {'email': response.user!.email, 'id': response.user!.id},
          );
        }
      } else {
        _showUnconfirmedPopup();
      }
    } catch (e) {
      if (e.toString().contains('Email not confirmed')) {
        _showUnconfirmedPopup();
      } else {
        if (mounted) context.showAppSnackBar(e.toString(), isError: true);
      }
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
    final state = ref.watch(emailConfirmationControllerProvider);
    final bool emailSent = state.value ?? false;
    final bool isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(emailSent ? 'Confirm Email' : 'Create Password'),
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
                    if (!emailSent)
                      PasswordSetupForm(
                        email: widget.email,
                        passwordController: _passwordController,
                        confirmPasswordController: _confirmPasswordController,
                      )
                    else
                      VerifyEmailView(email: widget.email),

                    const SizedBox(height: 48),
                    ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : (emailSent ? _checkConfirmation : _signUp),
                      child: isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(emailSent ? 'Continue' : 'Sign Up'),
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
