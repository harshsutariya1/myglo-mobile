import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/data/auth_repository.dart';
import '../../features/authentication/presentation/email_auth_screen.dart';
import '../../features/authentication/presentation/email_confirmation_screen.dart';
import '../../features/authentication/presentation/role_selection_screen.dart';
import '../../features/authentication/presentation/splash_screen.dart';
import '../../features/discovery_feed/presentation/home_screen.dart';
import '../../features/provider_profiles/presentation/profile_screen.dart';
import '../../features/provider_profiles/presentation/settings_screen.dart';
import '../widgets/main_scaffold.dart';

/// Defines all the route names and paths in the app.
enum AppRoute {
  splash(path: '/'),
  auth(path: '/auth'),
  confirmEmail(path: '/confirm_email'),
  roleSelection(path: '/role'),
  main(path: '/main'),
  discover(path: '/discover'),
  bookings(path: '/bookings'),
  profile(path: '/profile'),
  settings(path: 'settings');

  final String path;
  const AppRoute({required this.path});
}

final List<RouteBase> _appRoutes = [
  GoRoute(
    path: AppRoute.splash.path,
    name: AppRoute.splash.name,
    builder: (context, state) => const SplashScreen(),
  ),
  GoRoute(
    path: AppRoute.auth.path,
    name: AppRoute.auth.name,
    builder: (context, state) => const EmailAuthScreen(),
  ),
  GoRoute(
    path: AppRoute.confirmEmail.path,
    name: AppRoute.confirmEmail.name,
    builder: (context, state) {
      final extra = state.extra as Map<String, dynamic>? ?? {};
      return EmailConfirmationScreen(email: extra['email'] as String? ?? '');
    },
  ),
  GoRoute(
    path: AppRoute.roleSelection.path,
    name: AppRoute.roleSelection.name,
    builder: (context, state) => const RoleSelectionScreen(),
  ),
  ShellRoute(
    builder: (context, state, child) {
      return MainScaffold(child: child);
    },
    routes: [
      GoRoute(
        path: AppRoute.main.path,
        name: AppRoute.main.name,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoute.discover.path,
        name: AppRoute.discover.name,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Discover'))),
      ),
      GoRoute(
        path: AppRoute.bookings.path,
        name: AppRoute.bookings.name,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Bookings'))),
      ),
      GoRoute(
        path: AppRoute.profile.path,
        name: AppRoute.profile.name,
        builder: (context, state) => const ProfileScreen(),
        routes: [
          GoRoute(
            path: AppRoute.settings.path,
            name: AppRoute.settings.name,
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  ),
];

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoute.splash.path,
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final isAuth = authState.value?.session != null;

      final isLoggingInOrSplash =
          state.uri.path == AppRoute.auth.path ||
          state.uri.path == AppRoute.splash.path ||
          state.uri.path == AppRoute.confirmEmail.path;

      // Redirect to splash/auth if not authenticated.
      if (!isAuth && !isLoggingInOrSplash) {
        return AppRoute.splash.path;
      }

      // If authenticated and trying to access auth/splash screens,
      // redirect to the main app feed (unless still confirming email).
      if (isAuth &&
          isLoggingInOrSplash &&
          state.uri.path != AppRoute.confirmEmail.path) {
        return AppRoute.main.path;
      }

      return null;
    },
    routes: _appRoutes,
  );
});
