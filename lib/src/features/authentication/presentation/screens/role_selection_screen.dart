import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../domain/user_role.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  UserRole? _selectedRole;
  bool _isLoading = false;

  Future<void> _submitRole() async {
    if (_selectedRole == null) return;

    developer.log(
      'Starting role submission with selected role: ${_selectedRole!.name}',
      name: 'RoleSelectionScreen',
    );
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      developer.log(
        'Calling supabase.auth.updateUser to set role metadata',
        name: 'RoleSelectionScreen',
      );
      await supabase.auth.updateUser(
        UserAttributes(data: {'role': _selectedRole!.name}),
      );

      developer.log(
        'Role metadata updated successfully. Navigating to /onboarding_details',
        name: 'RoleSelectionScreen',
      );
      if (mounted) {
        context.push('/onboarding_details', extra: {'role': _selectedRole});
      }
    } catch (e) {
      developer.log(
        'Exception during role submission: $e',
        level: 1000,
        name: 'RoleSelectionScreen',
      );
      if (mounted) {
        context.showAppSnackBar(e.toString(), isError: true);
      }
    } finally {
      developer.log('Role submission completed', name: 'RoleSelectionScreen');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkRed,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'How would you like to use the app moving forward?',
                style: TextStyle(fontSize: 18, color: AppTheme.darkRed),
              ),
              const SizedBox(height: 32),
              _buildRoleCard(
                title: 'I\'m a customer',
                subtitle: 'Looking for beauty services',
                icon: Icons.shopping_bag_outlined,
                role: UserRole.customer,
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                title: 'I\'m a business',
                subtitle: 'Selling my beauty services',
                icon: Icons.work_outline,
                role: UserRole.business,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedRole == null || _isLoading
                      ? null
                      : _submitRole,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required UserRole role,
  }) {
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.burntOrange : Colors.black12,
            width: isSelected ? 2 : 1,
          ),
          color: AppTheme.white,
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: AppTheme.darkRed),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkRed,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? AppTheme.burntOrange : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
