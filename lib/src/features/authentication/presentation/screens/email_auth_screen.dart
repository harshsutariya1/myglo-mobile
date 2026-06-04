import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../data/auth_repository.dart';
import '../controllers/email_auth_controller.dart';

class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

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
      final supabase = ref.read(supabaseClientProvider);

      developer.log(
        'Checking auth.users table via RPC to see if user exists',
        name: 'EmailAuthScreen',
      );
      bool exists = false;
      try {
        final res = await supabase.rpc('check_user_exists', params: {'p_email': email});
        if (res == true) {
          exists = true;
        }
      } catch (e) {
        developer.log(
          'Error checking user existence: $e',
          level: 900,
          name: 'EmailAuthScreen',
        );
      }

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
      developer.log('Calling login on emailAuthController...', name: 'EmailAuthScreen');
      await ref.read(emailAuthControllerProvider.notifier).login(email, password);

      developer.log(
        'Login successful. Navigating to /main.',
        name: 'EmailAuthScreen',
      );
      if (mounted) {
        context.go('/main');
      }
    } on AuthException catch (e) {
      if (e.message.contains('Email not confirmed')) {
        developer.log(
          'Email not confirmed during login',
          name: 'EmailAuthScreen',
        );
        _showUnconfirmedPopup();
      } else {
        developer.log(
          'AuthException during login: ${e.message}',
          level: 900,
          name: 'EmailAuthScreen',
        );
        if (mounted) context.showAppSnackBar('Authentication failed. Please check your credentials.', isError: true);
      }
    } catch (e) {
      developer.log(
        'Unexpected exception during login: $e',
        level: 1000,
        name: 'EmailAuthScreen',
      );
      if (mounted) context.showAppSnackBar('An unexpected error occurred. Please try again later.', isError: true);
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
                    Image.asset(
                      AppAssets.iconLogo1,
                      height: 80,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.star,
                        size: 80,
                        color: AppTheme.peach,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome to MyGlo',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkRed,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter your email to log in or create an account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 32),

                    // Fixed Email Field wrapper
                    Container(
                      color: Theme.of(
                        context,
                      ).scaffoldBackgroundColor, // Background to prevent transparency clash
                      child: TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),

                    // Animated Password Dropdown
                    ClipRect(
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          return Align(
                            alignment: Alignment.topCenter,
                            heightFactor: _animation.value,
                            child: FractionalTranslation(
                              translation: Offset(0, _animation.value - 1.0),
                              child: child,
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 4.0,
                                  bottom: 8.0,
                                  top: 4.0,
                                ),
                                child: Text(
                                  'Account found! Please enter your password.',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              TextField(
                                controller: _passwordController,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Theme.of(context).colorScheme.outlineVariant,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Theme.of(context).colorScheme.outlineVariant,
                                    ),
                                  ),
                                ),
                                obscureText: true,
                              ),
                            ],
                          ),
                        ),
                      ),
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
