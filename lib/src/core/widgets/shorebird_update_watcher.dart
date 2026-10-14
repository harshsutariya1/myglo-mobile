import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../services/shorebird_update_service.dart';

/// Looks for a new Shorebird patch on launch, whenever the app comes back to
/// the foreground, and every [AppConfig.appUpdateCheckInterval] while it stays
/// open. A patch it finds downloads silently; [AppUpdateBanner] on the home
/// screens asks for a restart once it is installed.
class ShorebirdUpdateWatcher extends ConsumerStatefulWidget {
  const ShorebirdUpdateWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ShorebirdUpdateWatcher> createState() => _ShorebirdUpdateWatcherState();
}

class _ShorebirdUpdateWatcherState extends ConsumerState<ShorebirdUpdateWatcher> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // After the first frame, so the check never delays startup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(shorebirdUpdateServiceProvider.notifier).isAvailable) return;
      _check();
      _startTimer();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!ref.read(shorebirdUpdateServiceProvider.notifier).isAvailable) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _check();
        _startTimer();
      case AppLifecycleState.paused || AppLifecycleState.hidden || AppLifecycleState.detached:
        _timer?.cancel();
        _timer = null;
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(AppConfig.appUpdateCheckInterval, (_) => _check());
  }

  void _check() {
    // Failures are logged and reported inside the service.
    unawaited(ref.read(shorebirdUpdateServiceProvider.notifier).checkForUpdate());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
