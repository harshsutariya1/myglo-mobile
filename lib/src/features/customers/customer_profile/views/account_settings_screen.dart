import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../../shared/authentication/controllers/session_actions.dart';
import '../../../shared/notifications/push/push_notifications_controller.dart';
import '../../../shared/notifications/push/push_settings.dart';
import 'widgets/profile_menu_tile.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pushStatus = ref.watch(pushNotificationsProvider).value;
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Account Settings',
          style: TextStyle(
            color: context.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: context.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: context.colorScheme.onSurface),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            if (pushStatus != PushStatus.unsupported) ...[
              const _PushNotificationsTile(),
              Divider(color: Colors.grey.shade300, height: 1),
            ],
            ProfileMenuTile(
              title: 'Forgot Password',
              icon: Icons.lock_reset,
              onTap: () => _showUnderDevelopment(context),
            ),
            Divider(color: Colors.grey.shade300, height: 1),
            ProfileMenuTile(
              title: 'Log Out',
              icon: Icons.logout,
              isDestructive: true,
              onTap: () => _showLogoutDialog(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnderDevelopment(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.construction, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text('Feature under development', style: TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    final outerContext = context;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to log out of your account?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                try {
                  await ref.read(sessionActionsProvider).signOut();
                } catch (e, st) {
                  AppLogger.e('Sign out failed', tag: 'AccountSettings', error: e, stackTrace: st);
                  if (outerContext.mounted) {
                    outerContext.showAppSnackBar("Couldn't log you out. Please try again.", isError: true);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colorScheme.error,
                foregroundColor: context.colorScheme.onError,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Log Out',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Push notifications on/off for this phone.
class _PushNotificationsTile extends ConsumerStatefulWidget {
  const _PushNotificationsTile();

  @override
  ConsumerState<_PushNotificationsTile> createState() => _PushNotificationsTileState();
}

class _PushNotificationsTileState extends ConsumerState<_PushNotificationsTile> with PushToggleState {
  @override
  Widget build(BuildContext context) {
    final model = PushToggleModel.of(ref.watch(pushNotificationsProvider).value);
    final busy = pendingPushValue != null;
    final value = pendingPushValue ?? model.value;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.notifications_active_outlined, color: context.colorScheme.primary, size: 22),
      ),
      title: const Text('Push notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      subtitle: Text(model.subtitle, style: TextStyle(fontSize: 12.5, color: context.colorScheme.onSurface.withValues(alpha: 0.55))),
      onTap: model.enabled && !busy ? () => setPush(!value) : null,
      trailing: Switch.adaptive(value: value, onChanged: model.enabled && !busy ? setPush : null),
    );
  }
}
