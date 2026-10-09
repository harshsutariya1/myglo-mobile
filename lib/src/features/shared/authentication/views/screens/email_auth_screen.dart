import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/routing/app_router.dart';
import '../../../../../core/utils/app_logger.dart';
import '../../../../../core/widgets/snackbar_utils.dart';
import '../../controllers/email_auth_controller.dart';
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
  final _passwordController = TextEditingController(text: '123456'); //default password during development only

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

  /// The account exists but its email was never confirmed: send a fresh code
  /// and take the user to the code-entry screen.
  void _startVerification(String email) {
    if (!mounted) return;
    context.push(
      AppRoute.confirmEmail.path,
      extra: {'email': email, 'verifyOnly': true},
    );
  }

  Future<void> _handleContinue() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !_isValidEmail) return;

    AppLogger.d('EmailAuthScreen: Checking account status for $email', tag: 'EmailAuth');
    setState(() => _isLoading = true);

    try {
      final exists = await ref
          .read(emailAuthControllerProvider.notifier)
          .checkUserExists(email);

      if (exists) {
        AppLogger.i('EmailAuthScreen: Account found for $email. Prompting for password.', tag: 'EmailAuth');
        setState(() {
          _accountExists = true;
          _isLoading = false;
        });
        _animController.forward();
      } else {
        AppLogger.i('EmailAuthScreen: Account not found for $email. Navigating to email confirmation.', tag: 'EmailAuth');
        if (mounted) {
          setState(() => _isLoading = false);
          context.push(AppRoute.confirmEmail.path, extra: {'email': email});
        }
      }
    } catch (e, st) {
      AppLogger.e('EmailAuthScreen: Unexpected error in handleContinue', tag: 'EmailAuth', error: e, stackTrace: st);
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

    AppLogger.d('EmailAuthScreen: Starting login for $email', tag: 'EmailAuth');
    setState(() => _isLoading = true);

    try {
      await ref
          .read(emailAuthControllerProvider.notifier)
          .login(email, password);

      AppLogger.i('EmailAuthScreen: Login successful. Routing via guard.', tag: 'EmailAuth');
      if (mounted) {
        // The router guard sends a signed-in user to the right home / onboarding screen.
        context.go(AppRoute.splash.path);
      }
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('email not confirmed') ||
          e.code == 'email_not_confirmed') {
        AppLogger.w('EmailAuthScreen: Email not confirmed during login for $email', tag: 'EmailAuth');
        _startVerification(email);
      } else {
        AppLogger.w('EmailAuthScreen: AuthException during login: ${e.message}', tag: 'EmailAuth');
        if (mounted) {
          context.showAppSnackBar(
            'Authentication failed. Please check your credentials.',
            isError: true,
          );
        }
      }
    } catch (e, st) {
      AppLogger.e('EmailAuthScreen: Unexpected exception during login', tag: 'EmailAuth', error: e, stackTrace: st);
      if (mounted) {
        context.showAppSnackBar('An unexpected error occurred.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(emailAuthControllerProvider);
    return Scaffold(
      appBar: AppBar(
        // Sign-in is the first screen once the intro has been seen, so
        // there's not always anything to go back to.
        automaticallyImplyLeading: false,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
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
                    Spacer(),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(color: context.colorScheme.onSurface, fontSize: 12),
                        children: [
                          TextSpan(text: 'By continuing you agree to our '),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(color: context.colorScheme.secondary),
                          ),
                          TextSpan(text: '\nand '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(color: context.colorScheme.secondary),
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
