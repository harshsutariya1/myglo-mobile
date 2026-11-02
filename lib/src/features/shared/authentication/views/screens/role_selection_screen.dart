import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/app_logger.dart';
import '../../../../../core/widgets/snackbar_utils.dart';
import '../../controllers/session_actions.dart';
import '../../models/user_role.dart';
import '../../models/user_repository.dart';
import '../../models/auth_repository.dart';
import '../../controllers/user_profile_provider.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  final String email;
  final String id;
  const RoleSelectionScreen({super.key, required this.email, required this.id});

  @override
  ConsumerState<RoleSelectionScreen> createState() =>
      _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  UserRole? _selectedRole;
  bool _isLoading = false;
  bool _isSigningOut = false;

  Future<void> _submitRole() async {
    if (_selectedRole == null) return;

    AppLogger.d(
      'RoleSelectionScreen: Submitting role ${_selectedRole!.name} for user ${widget.id}',
      tag: 'RoleSelection',
    );
    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final userRepo = ref.read(userRepositoryProvider);
      final container = ProviderScope.containerOf(context);
      // Source of truth is the session, not the route parameters (which can be lost in navigation).
      final user = authRepo.currentUser;
      final userId = user?.id ?? widget.id;
      final userEmail = user?.email ?? widget.email;

      AppLogger.d('RoleSelectionScreen: Updating auth metadata role', tag: 'RoleSelection');
      await authRepo.updateUserRole(role: _selectedRole!.name);

      AppLogger.d('RoleSelectionScreen: Registering role in database table', tag: 'RoleSelection');
      await userRepo.registerUserRole(
        id: userId,
        email: userEmail,
        role: _selectedRole!.name,
      );

      // Invalidate so the router sees the new profile state (avoids redirect loop)
      container.invalidate(userProfileProvider);

      AppLogger.i('RoleSelectionScreen: Role ${_selectedRole!.name} assigned successfully', tag: 'RoleSelection');
      if (mounted) {
        context.go('/onboarding_details');
      }
    } catch (e, st) {
      AppLogger.e('RoleSelectionScreen: Exception during role submission', tag: 'RoleSelection', error: e, stackTrace: st);
      if (mounted) {
        context.showAppSnackBar(
          'Failed to update role. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Lets someone who signed up with the wrong email (or just wants out)
  /// leave before choosing a role.
  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can sign in again any time to finish setting up your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.destructive, foregroundColor: Colors.white),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isSigningOut = true);
    try {
      await ref.read(sessionActionsProvider).signOut();
      if (mounted) context.go(AppRoute.splash.path);
    } catch (e, st) {
      AppLogger.e('Sign out from role selection failed', tag: 'RoleSelection', error: e, stackTrace: st);
      if (mounted) {
        setState(() => _isSigningOut = false);
        context.showAppSnackBar("Couldn't log you out. Please try again.", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isLoading || _isSigningOut;
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton.icon(
            onPressed: busy ? null : _confirmLogout,
            icon: _isSigningOut
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Log out'),
            style: TextButton.styleFrom(foregroundColor: context.colorScheme.onSurface),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'How would you like to use the app moving forward?',
                style: TextStyle(fontSize: 18, color: context.colorScheme.onSurface),
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
                title: 'I\'m a provider',
                subtitle: 'Selling my beauty services',
                icon: Icons.work_outline,
                role: UserRole.provider,
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: context.colorScheme.onSurface.withValues(alpha: 0.55)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      RoleSelectionCopy.note,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: context.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedRole == null || busy
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
            color: isSelected
                ? context.colorScheme.secondary
                : Theme.of(context).colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          color: context.colorScheme.surface,
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: context.colorScheme.onSurface),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.colorScheme.onSurface,
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
              color: isSelected
                  ? context.colorScheme.secondary
                  : Theme.of(context).colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

/// Copy for the role selection screen.
class RoleSelectionCopy {
  RoleSelectionCopy._();

  static const String note =
      "You can't change your role once you've chosen it. You can delete your account at any time in Settings.";
}
