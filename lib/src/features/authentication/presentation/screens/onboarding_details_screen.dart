import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../domain/user_role.dart';
import '../../application/user_profile_provider.dart';

import '../../domain/business_model.dart';
import '../../domain/customer_model.dart';
import '../../data/user_repository.dart';

class OnboardingDetailsScreen extends ConsumerStatefulWidget {
  final UserRole role;

  const OnboardingDetailsScreen({super.key, required this.role});

  @override
  ConsumerState<OnboardingDetailsScreen> createState() =>
      _OnboardingDetailsScreenState();
}

class _OnboardingDetailsScreenState
    extends ConsumerState<OnboardingDetailsScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitDetails() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || phone.isEmpty) {
      context.showAppSnackBar('Please fill all the details', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('No user found');

      final table = widget.role == UserRole.business
          ? 'businesses'
          : 'customers';

      // Ensure user metadata role is set as well
      await supabase.auth.updateUser(
        UserAttributes(data: {'role': widget.role.name}),
      );

      final userRepo = ref.read(userRepositoryProvider);

      if (widget.role == UserRole.business) {
        final business = BusinessModel(
          id: user.id,
          email: user.email ?? '',
          firstName: firstName,
          lastName: lastName,
          phone: phone,
        );
        await userRepo.saveBusiness(business);
      } else {
        final customer = CustomerModel(
          id: user.id,
          email: user.email ?? '',
          firstName: firstName,
          lastName: lastName,
          phone: phone,
        );
        await userRepo.saveCustomer(customer);
      }

      // Invalidate the profile provider so it re-fetches with new data
      ref.invalidate(userProfileProvider);

      developer.log(
        'Successfully saved details to $table',
        name: 'OnboardingDetailsScreen',
      );

      if (mounted) {
        context.go('/main');
      }
    } catch (e) {
      developer.log(
        'Error saving details: $e',
        level: 1000,
        name: 'OnboardingDetailsScreen',
      );
      if (mounted) context.showAppSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Let\'s get to know you!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkRed,
                ),
              ),
              const SizedBox(height: 32),

              // Instead of separate screens, we do it in a single screen as requested
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: AppTheme.burntOrange.withValues(alpha: 0.2),
                  child: const Icon(
                    Icons.add_a_photo,
                    size: 40,
                    color: AppTheme.burntOrange,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Add a profile picture (Optional)',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 32),

              TextField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last name',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitDetails,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Complete'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
