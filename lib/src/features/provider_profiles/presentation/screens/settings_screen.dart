import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/services/shorebird_update_service.dart';
import '../../../authentication/data/auth_repository.dart';
import 'package:restart_app/restart_app.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Account Details'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.goNamed(AppRoute.accountDetails.name);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.notifications_none),
                title: const Text('Notifications'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.security),
                title: const Text('Privacy & Security'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              const Divider(),
              Consumer(
                builder: (context, ref, child) {
                  final updateState = ref.watch(shorebirdUpdateServiceProvider);
                  final isChecking = updateState.isChecking;
                  final isDownloading = updateState.isDownloading;
                  final isReady = updateState.isUpdateReadyToInstall;
                  final patchVersion = updateState.currentPatchVersion ?? 'None';

                  return ListTile(
                    leading: const Icon(Icons.system_update),
                    title: const Text('Check for Upgrade'),
                    subtitle: Text('Current Patch: $patchVersion'),
                    trailing: isChecking || isDownloading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : isReady
                            ? const Text('Ready to Install',
                                style: TextStyle(color: Colors.green))
                            : const Icon(Icons.chevron_right),
                    onTap: (isChecking || isDownloading)
                        ? null
                        : () async {
                            if (isReady) {
                              Restart.restartApp();
                              return;
                            }

                            final service =
                                ref.read(shorebirdUpdateServiceProvider.notifier);
                            final isAvailable = await service.checkForUpdate();

                            if (context.mounted) {
                              if (isAvailable) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Update Available'),
                                    content: const Text(
                                        'A new update is available. Do you want to download it now?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('Later'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          service.downloadUpdate().then((_) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                      'Update downloaded. Please restart the app.'),
                                                ),
                                              );
                                            }
                                          });
                                        },
                                        child: const Text('Download'),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('App is up to date!')),
                                );
                              }
                            }
                          },
                  );
                },
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.burntOrange,
                    side: const BorderSide(color: AppTheme.burntOrange),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    'Logout',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.burntOrange,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );

                    if (shouldLogout == true) {
                      await ref.read(authRepositoryProvider).signOut();
                      if (context.mounted) {
                        context.go('/');
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
