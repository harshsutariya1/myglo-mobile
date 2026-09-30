import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';

/// Shows a blocking "No Internet Connection" sheet above the whole app while
/// the backend is unreachable.
///
/// It is meant for `MaterialApp.router(builder: ...)`. The sheet is a sibling
/// layered over the router rather than a pushed route, so the navigation
/// history, open dialogs / bottom sheets and any unsaved form state underneath
/// are left untouched, and the sheet disappears on its own when the connection
/// is restored.
class OfflineOverlay extends ConsumerStatefulWidget {
  const OfflineOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OfflineOverlay> createState() => _OfflineOverlayState();
}

class _OfflineOverlayState extends ConsumerState<OfflineOverlay>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Registered before the router's own observer, so while the sheet is up the
    // system back button is consumed here instead of popping routes underneath.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(networkStatusProvider.notifier).recheck();
    }
  }

  @override
  Future<bool> didPopRoute() async {
    return ref.read(networkStatusProvider) == NetworkStatus.offline;
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(networkStatusProvider) == NetworkStatus.offline;

    // `child` keeps a fixed position in the Stack so it is never re-mounted.
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: isOffline
                ? const _OfflineSheet(key: ValueKey('offline'))
                : const SizedBox.shrink(key: ValueKey('online')),
          ),
        ),
      ],
    );
  }
}

class _OfflineSheet extends ConsumerStatefulWidget {
  const _OfflineSheet({super.key});

  @override
  ConsumerState<_OfflineSheet> createState() => _OfflineSheetState();
}

class _OfflineSheetState extends ConsumerState<_OfflineSheet> {
  bool _retrying = false;
  bool _stillOffline = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _stillOffline = false;
    });
    final reachable = await ref
        .read(networkStatusProvider.notifier)
        .recheck(userInitiated: true);
    if (!mounted) return;
    setState(() {
      _retrying = false;
      _stillOffline = !reachable;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return BlockSemantics(
      child: Stack(
        children: [
          const ModalBarrier(dismissible: false, color: Colors.black54),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Material(
                color: scheme.surface,
                elevation: 12,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: Semantics(
                      liveRegion: true,
                      container: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: OfflineIllustration()),
                          const SizedBox(height: 24),
                          Text(
                            OfflineCopy.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            OfflineCopy.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: scheme.onSurface.withValues(alpha: 0.75),
                            ),
                          ),
                          if (_stillOffline) ...[
                            const SizedBox(height: 12),
                            Text(
                              OfflineCopy.stillOffline,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: scheme.secondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _retrying ? null : _retry,
                            child: _retrying
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(OfflineCopy.retry),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Copy for the offline sheet.
class OfflineCopy {
  OfflineCopy._();

  static const String title = 'No Internet Connection';
  static const String description =
      "You're offline right now. Check your Wi-Fi or mobile data. "
      "Nothing you've entered is lost, and we'll carry on once you're back online.";
  static const String stillOffline = 'Still offline. Please try again.';
  static const String retry = 'Retry';
}

/// Code-drawn placeholder illustration (the project has no offline asset yet).
/// Swap the body for an image / Lottie once design provides one.
class OfflineIllustration extends StatelessWidget {
  const OfflineIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return ExcludeSemantics(
      child: SizedBox(
        width: 132,
        height: 132,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer.withValues(alpha: 0.35),
              ),
            ),
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.tertiary.withValues(alpha: 0.55),
              ),
            ),
            Icon(Icons.wifi_off_rounded, size: 46, color: scheme.onSurface),
            Positioned(
              top: 10,
              right: 18,
              child: _dot(scheme.primary, 12),
            ),
            Positioned(
              bottom: 16,
              left: 14,
              child: _dot(scheme.secondary, 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
