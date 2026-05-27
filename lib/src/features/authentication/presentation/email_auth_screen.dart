import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../data/auth_repository.dart';

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
        'Querying profiles table to check if user exists',
        name: 'EmailAuthScreen',
      );
      bool exists = false;
      try {
        // Without an RPC, the standard approach is to query a public 'profiles' or 'users' table
        // that mirrors your auth.users table. If you don't have this, Supabase Auth prevents
        // enumeration by default and will always give vague errors on purpose.
        final res = await supabase
            .from('profiles')
            .select('id')
            .eq('email', email)
            .maybeSingle();

        developer.log(
          'Profiles table query result: $res',
          name: 'EmailAuthScreen',
        );
        exists = res != null;
      } catch (e) {
        developer.log(
          'Error querying profiles table (missing table or RLS): $e',
          level: 900,
          name: 'EmailAuthScreen',
        );
        // If the table doesn't exist yet or there's RLS blocking it, default to false.
        exists = false;
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
      final supabase = ref.read(supabaseClientProvider);
      developer.log('Calling signInWithPassword...', name: 'EmailAuthScreen');
      await supabase.auth.signInWithPassword(email: email, password: password);

      developer.log(
        'Login successful. Navigating to /main.',
        name: 'EmailAuthScreen',
      );
      if (mounted) {
        context.go('/main');
      }
    } on AuthException catch (e) {
      developer.log(
        'Supabase AuthException during login: ${e.message}',
        level: 900,
        name: 'EmailAuthScreen',
      );
      if (mounted) context.showAppSnackBar(e.message, isError: true);
    } catch (e) {
      developer.log(
        'Unexpected exception during login: $e',
        level: 1000,
        name: 'EmailAuthScreen',
      );
      if (mounted) context.showAppSnackBar(e.toString(), isError: true);
    } finally {
      developer.log('handleLogin completed', name: 'EmailAuthScreen');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                            borderSide: const BorderSide(color: Colors.black12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.black12),
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
                              const Padding(
                                padding: EdgeInsets.only(
                                  left: 4.0,
                                  bottom: 8.0,
                                  top: 4.0,
                                ),
                                child: Text(
                                  'Account found! Please enter your password.',
                                  style: TextStyle(
                                    color: Colors.green,
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
                                    borderSide: const BorderSide(
                                      color: Colors.black12,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.black12,
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
