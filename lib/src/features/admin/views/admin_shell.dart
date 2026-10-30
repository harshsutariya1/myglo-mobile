import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/adaptive/adaptive_list_detail.dart';
import '../../shared/authentication/controllers/session_actions.dart';
import '../controllers/admin_actions.dart';
import '../controllers/admin_controllers.dart';
import 'widgets/totp_code_form.dart';

/// The admin area's frame: a bottom bar on phones, a navigation rail on wide
/// screens, and the idle lock.
///
/// The lock is a convenience on top of the server's checks (which refuse
/// any admin call without a recent authenticator code): after
/// [AppConfig.adminIdleLock] without a touch, or that long in the
/// background, the area is covered until the admin enters a new code.
class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const destinations = [
    (route: AppRoute.adminHome, label: 'Home', icon: Icons.space_dashboard_outlined, selectedIcon: Icons.space_dashboard),
    (route: AppRoute.adminPeople, label: 'People', icon: Icons.people_outline, selectedIcon: Icons.people),
    (route: AppRoute.adminPayments, label: 'Payments', icon: Icons.payments_outlined, selectedIcon: Icons.payments),
    (route: AppRoute.adminModeration, label: 'Moderation', icon: Icons.shield_outlined, selectedIcon: Icons.shield),
    (route: AppRoute.adminSettings, label: 'Settings', icon: Icons.tune_outlined, selectedIcon: Icons.tune),
  ];

  /// Index of the destination [location] is in.
  static int selectedIndex(String location) {
    for (var i = destinations.length - 1; i > 0; i--) {
      final path = destinations[i].route.path;
      if (location == path || location.startsWith('$path/')) return i;
    }
    return 0;
  }

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> with WidgetsBindingObserver {
  Timer? _idle;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetIdle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idle?.cancel();
    super.dispose();
  }

  void _resetIdle() {
    _idle?.cancel();
    _idle = Timer(AppConfig.adminIdleLock, () {
      if (mounted) ref.read(adminLockProvider.notifier).lock();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _backgroundedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final away = _backgroundedAt;
        _backgroundedAt = null;
        if (away != null && DateTime.now().difference(away) >= AppConfig.adminIdleLock) {
          ref.read(adminLockProvider.notifier).lock();
        }
        _resetIdle();
      default:
        break;
    }
  }

  void _go(int index) => context.goNamed(AdminShell.destinations[index].route.name);

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(adminLockProvider);
    final selected = AdminShell.selectedIndex(widget.location);
    final wide = isWideLayout(context);

    final body = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetIdle(),
      child: widget.child,
    );

    return Stack(
      children: [
        Scaffold(
          body: wide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: selected,
                      onDestinationSelected: _go,
                      labelType: NavigationRailLabelType.all,
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Icon(Icons.admin_panel_settings, color: context.colorScheme.secondary, size: 30),
                      ),
                      destinations: [
                        for (final d in AdminShell.destinations)
                          NavigationRailDestination(
                            icon: Icon(d.icon),
                            selectedIcon: Icon(d.selectedIcon),
                            label: Text(d.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: body),
                  ],
                )
              : body,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: selected,
                  onDestinationSelected: _go,
                  destinations: [
                    for (final d in AdminShell.destinations)
                      NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
                  ],
                ),
        ),
        if (locked) const Positioned.fill(child: _LockedView()),
      ],
    );
  }
}

/// Covers the admin area until the admin enters a new authenticator code.
class _LockedView extends ConsumerWidget {
  const _LockedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final mfa = ref.watch(adminMfaStateProvider);
    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 52, color: scheme.secondary),
                  const SizedBox(height: 14),
                  Text(
                    'Admin area locked',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scheme.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter a code from your authenticator app to carry on.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: scheme.onSurface.withValues(alpha: 0.65)),
                  ),
                  const SizedBox(height: 24),
                  switch (mfa) {
                    AsyncData(:final value) when value.verifiedFactorId != null => TotpCodeForm(
                        factorId: value.verifiedFactorId!,
                        onVerified: () {
                          ref.invalidate(adminMfaStateProvider);
                          ref.read(adminLockProvider.notifier).unlock();
                        },
                      ),
                    AsyncError() => OutlinedButton(
                        onPressed: () => ref.invalidate(adminMfaStateProvider),
                        child: const Text('Try again'),
                      ),
                    _ => const CircularProgressIndicator(),
                  },
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      ref.read(adminLockProvider.notifier).unlock();
                      ref.read(sessionActionsProvider).signOut();
                    },
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
