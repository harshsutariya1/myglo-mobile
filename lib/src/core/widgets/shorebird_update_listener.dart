import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restart_app/restart_app.dart';
import '../services/shorebird_update_service.dart';
import '../theme/app_theme.dart';

class ShorebirdUpdateListener extends ConsumerStatefulWidget {
  final Widget child;

  const ShorebirdUpdateListener({super.key, required this.child});

  @override
  ConsumerState<ShorebirdUpdateListener> createState() =>
      _ShorebirdUpdateListenerState();
}

class _ShorebirdUpdateListenerState
    extends ConsumerState<ShorebirdUpdateListener> {
  bool _hasChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasChecked) {
        _hasChecked = true;
        _checkAndDownloadUpdate();
      }
    });
  }

  Future<void> _checkAndDownloadUpdate() async {
    final service = ref.read(shorebirdUpdateServiceProvider.notifier);
    final isAvailable = await service.checkForUpdate();

    if (isAvailable && mounted) {
      await service.downloadUpdate();

      final state = ref.read(shorebirdUpdateServiceProvider);
      if (state.isUpdateReadyToInstall && mounted) {
        _showUpdateReadyPopup();
      }
    }
  }

  void _showUpdateReadyPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Update Ready'),
        content: const Text(
          'A new update has been downloaded automatically. '
          'Would you like to restart the app now to apply the changes?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.burntOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              Restart.restartApp();
            },
            child: const Text('Restart Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
