import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/shorebird_update_service.dart';
import '../theme/app_theme.dart';

/// "Update ready" card for the top of the home screens. Takes no space until
/// a Shorebird patch has downloaded in the background and is waiting for a
/// restart; its button then restarts into it.
class AppUpdateBanner extends ConsumerWidget {
  const AppUpdateBanner({super.key, this.margin = EdgeInsets.zero});

  final EdgeInsets margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shorebirdUpdateServiceProvider);
    final canRestartInApp = ref.watch(appRestarterProvider).canRestartInApp;
    final scheme = context.colorScheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !state.needsRestart
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: margin,
              child: Container(
                key: const ValueKey('app-update-banner'),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.peach.withValues(alpha: 0.35), AppTheme.primaryPink.withValues(alpha: 0.16)],
                  ),
                  border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.system_update_rounded, color: scheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              'Update ready',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scheme.onSurface),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _message(state, canRestartInApp: canRestartInApp),
                            style: TextStyle(fontSize: 13, height: 1.35, color: scheme.onSurface.withValues(alpha: 0.65)),
                          ),
                          const SizedBox(height: 10),
                          _RestartButton(restarting: state.phase == ShorebirdUpdatePhase.restarting),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  static String _message(ShorebirdUpdateState state, {required bool canRestartInApp}) {
    if (state.error == ShorebirdUpdateError.restartFailed || !canRestartInApp) {
      return 'Close Myglo and open it again to start using the latest version.';
    }
    return 'Restart Myglo to start using the latest version.';
  }
}

class _RestartButton extends ConsumerWidget {
  const _RestartButton({required this.restarting});

  final bool restarting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;

    return FilledButton(
      onPressed: restarting
          ? null
          : () {
              HapticFeedback.selectionClick();
              restartIntoUpdate(context, ref);
            },
      style: FilledButton.styleFrom(
        backgroundColor: scheme.onSurface,
        foregroundColor: scheme.surface,
        // Keep the progress state readable rather than greyed out.
        disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.75),
        disabledForegroundColor: scheme.surface,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
      ),
      child: restarting
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    key: const ValueKey('app-update-progress'),
                    strokeWidth: 2,
                    color: scheme.surface,
                  ),
                ),
                const SizedBox(width: 10),
                const Text('Restarting'),
              ],
            )
          : const Text('Restart'),
    );
  }
}

/// Restarts into a downloaded patch, or explains how to when the app can't
/// restart itself (always on iOS).
Future<void> restartIntoUpdate(BuildContext context, WidgetRef ref) async {
  final started = await ref.read(shorebirdUpdateServiceProvider.notifier).restartToApply();
  if (started || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Finish updating'),
      content: const Text(
        'Close Myglo by swiping it away in the app switcher, then open it again. '
        'Your update is already downloaded and will be applied when the app reopens.',
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Got it')),
      ],
    ),
  );
}
