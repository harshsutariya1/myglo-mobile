import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../../features/shared/authentication/controllers/user_profile_provider.dart';

class MainScaffold extends ConsumerWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(userProfileProvider);
    final isProvider = profileState.value?.isProvider ?? false;

    return Scaffold(
      body: child,
      extendBody: true,
      bottomNavigationBar: _buildBottomNav(context, isProvider),
    );
  }

  Widget _buildBottomNav(BuildContext context, bool isProvider) {
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = _calculateSelectedIndex(location, isProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          child: NavigationBar(
            height: 55,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            backgroundColor: Colors.transparent,
            indicatorColor: AppTheme.peach.withValues(alpha: 0.3),
            selectedIndex: currentIndex,
            onDestinationSelected: (index) => _onItemTapped(index, context, isProvider),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined, color: Colors.white70),
                selectedIcon: Icon(Icons.home, color: AppTheme.peach),
                label: "Home",
              ),
              const NavigationDestination(
                icon: Icon(Icons.explore_outlined, color: Colors.white70),
                selectedIcon: Icon(Icons.explore, color: AppTheme.peach),
                label: 'Discover',
              ),
              if (isProvider)
                const NavigationDestination(
                  icon: Icon(Icons.business_center_outlined, color: Colors.white70),
                  selectedIcon: Icon(Icons.business_center, color: AppTheme.peach),
                  label: 'Business',
                )
              else
                const NavigationDestination(
                  icon: Icon(Icons.calendar_today_outlined, color: Colors.white70),
                  selectedIcon: Icon(Icons.calendar_today, color: AppTheme.peach),
                  label: 'Bookings',
                ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline, color: Colors.white70),
                selectedIcon: Icon(Icons.person, color: AppTheme.peach),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _calculateSelectedIndex(String location, bool isProvider) {
    if (location.startsWith('/customer_home') || location.startsWith('/provider_home')) return 0;
    if (location.startsWith('/discover')) return 1;
    if (location.startsWith('/business_tools') || location.startsWith('/bookings')) return 2;
    if (location.startsWith('/customer_profile') || location.startsWith('/provider_profile')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context, bool isProvider) {
    switch (index) {
      case 0:
        context.go(isProvider ? '/provider_home' : '/customer_home');
        break;
      case 1:
        context.go('/discover');
        break;
      case 2:
        context.go(isProvider ? '/business_tools' : '/bookings');
        break;
      case 3:
        context.go(isProvider ? '/provider_profile' : '/customer_profile');
        break;
    }
  }
}
