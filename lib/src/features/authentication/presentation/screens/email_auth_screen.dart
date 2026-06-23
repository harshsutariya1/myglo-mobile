import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../controllers/email_auth_controller.dart';
import '../widgets/auth_header.dart';
import '../widgets/email_field.dart';
import '../widgets/animated_password_field.dart';

class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController(text: "123456");

  bool _isLoading = false;
  bool _isValidEmail = false;
  bool _accountExists = false;

  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutQuart,
    );
    _emailController.addListener(_validateEmail);
  }

  void _validateEmail() {
    final valid = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    ).hasMatch(_emailController.text.trim());
    if (valid != _isValidEmail) {
      setState(() => _isValidEmail = valid);
    }
    if (_accountExists) {
      setState(() {
        _accountExists = false;
        _animController.reverse();
        _passwordController.clear();
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
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

  Future<void> _handleContinue() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !_isValidEmail) return;

    developer.log(
      'Starting handleContinue with email: $email',
      name: 'EmailAuthScreen',
    );
    setState(() => _isLoading = true);

    try {
      developer.log(
        'Checking auth.users table via RPC to see if user exists',
        name: 'EmailAuthScreen',
      );

      final exists = await ref
          .read(emailAuthControllerProvider.notifier)
          .checkUserExists(email);

      developer.log(
        'Finished user existence check. Exists: $exists',
        name: 'EmailAuthScreen',
      );

      if (exists) {
        developer.log(
          'Account found. Prompting for password.',
          name: 'EmailAuthScreen',
        );
        setState(() {
          _accountExists = true;
          _isLoading = false;
        });
        _animController.forward();
      } else {
        developer.log(
          'Account not found. Proceeding to email confirmation screen.',
          name: 'EmailAuthScreen',
        );
        if (mounted) {
          setState(() => _isLoading = false);
          context.push('/confirm_email', extra: {'email': email});
        }
      }
    } catch (e) {
      developer.log(
        'Unexpected error in handleContinue: $e',
        level: 1000,
        name: 'EmailAuthScreen',
      );
      if (mounted) {
        context.showAppSnackBar(e.toString(), isError: true);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) return;

    developer.log(
      'Starting handleLogin for email: $email',
      name: 'EmailAuthScreen',
    );
    setState(() => _isLoading = true);

    try {
      developer.log(
        'Calling login on emailAuthController...',
        name: 'EmailAuthScreen',
      );
      await ref
          .read(emailAuthControllerProvider.notifier)
          .login(email, password);

      developer.log(
        'Login successful. Navigating to /main.',
        name: 'EmailAuthScreen',
      );
      if (mounted) {
        context.go('/main');
      }
    } catch (e) {
      if (e.toString().contains('Email not confirmed')) {
        developer.log(
          'Email not confirmed during login',
          name: 'EmailAuthScreen',
        );
        _showUnconfirmedPopup();
      } else {
        developer.log(
          'Exception during login: $e',
          level: 900,
          name: 'EmailAuthScreen',
        );
        if (mounted) {
          context.showAppSnackBar(
            'Authentication failed. Please check your credentials.',
            isError: true,
          );
        }
      }
    } finally {
      developer.log('handleLogin completed', name: 'EmailAuthScreen');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(emailAuthControllerProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32),
                    const AuthHeader(),
                    const SizedBox(height: 32),

                    // Fixed Email Field wrapper
                    EmailField(controller: _emailController),

                    // Animated Password Dropdown
                    AnimatedPasswordField(
                      animation: _animation,
                      controller: _passwordController,
                    ),

                    const SizedBox(height: 32),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _isValidEmail ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: !_isValidEmail,
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : (_accountExists
                                      ? _handleLogin
                                      : _handleContinue),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(_accountExists ? 'Log In' : 'Continue'),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(color: AppTheme.darkRed, fontSize: 12),
                        children: [
                          TextSpan(text: 'By continuing you agree to our '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(color: AppTheme.burntOrange),
                          ),
                          TextSpan(text: '\nand '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(color: AppTheme.burntOrange),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
