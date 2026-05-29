import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/data/auth_repository.dart';
import '../../features/authentication/presentation/screens/email_auth_screen.dart';
import '../../features/authentication/presentation/screens/email_confirmation_screen.dart';
import '../../features/authentication/presentation/screens/role_selection_screen.dart';
import '../../features/authentication/presentation/screens/onboarding_details_screen.dart';
import '../../features/authentication/domain/user_role.dart';
import '../../features/authentication/presentation/screens/splash_screen.dart';
import '../../features/authentication/presentation/screens/intro_screen.dart';
import '../../features/discovery_feed/presentation/home_screen.dart';
import '../../features/provider_profiles/presentation/screens/profile_screen.dart';
import '../../features/provider_profiles/presentation/screens/settings_screen.dart';
import '../../features/provider_profiles/presentation/screens/account_details_screen.dart';
import '../../features/authentication/application/user_profile_provider.dart';
import '../widgets/main_scaffold.dart';

/// Defines all the route names and paths in the app.
enum AppRoute {
  splash(path: '/'),
  intro(path: '/intro'),
  auth(path: '/auth'),
  confirmEmail(path: '/confirm_email'),
  roleSelection(path: '/role'),
  onboardingDetails(path: '/onboarding_details'),
  main(path: '/main'),
  discover(path: '/discover'),
  bookings(path: '/bookings'),
  profile(path: '/profile'),
  settings(path: 'settings'),
  accountDetails(path: 'account-details');

  final String path;
  const AppRoute({required this.path});
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoute.splash.path,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final userProfileState = ref.read(userProfileProvider);

      if (authState.isLoading) return AppRoute.splash.path;

      final session = authState.value?.session;
      final isAuth = session != null;

      final isUnauthRoute =
          state.uri.path == AppRoute.auth.path ||
          state.uri.path == AppRoute.intro.path ||
          state.uri.path == AppRoute.confirmEmail.path;

      final isAuthRouteOrSplash =
          isUnauthRoute ||
          state.uri.path == AppRoute.splash.path ||
          state.uri.path == AppRoute.roleSelection.path ||
          state.uri.path == AppRoute.onboardingDetails.path;

      // Redirect to intro if not authenticated.
      if (!isAuth) {
        if (!isUnauthRoute) return AppRoute.intro.path;
        return null;
      }

      // If user is authenticated, check their onboarding status
      if (userProfileState.isLoading && !userProfileState.hasValue) {
        return AppRoute.splash.path; // Show splash while loading profile
      }

      final profile = userProfileState.value;

      // 1. Not in all_users table -> Role Selection
      if (profile == null) {
        if (state.uri.path != AppRoute.roleSelection.path) {
          return '${AppRoute.roleSelection.path}?email=${session.user.email}&id=${session.user.id}';
        }
        return null;
      }

      // 2. In all_users but missing details -> Onboarding
      if (profile.allUser.firstName == null || profile.allUser.firstName!.isEmpty) {
        if (state.uri.path != AppRoute.onboardingDetails.path) {
          return AppRoute.onboardingDetails.path;
        }
        return null;
      }

      // 3. Fully onboarded -> Redirect to main if on auth screens
      if (isAuthRouteOrSplash) {
        return AppRoute.main.path;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoute.splash.path,
        name: AppRoute.splash.name,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoute.intro.path,
        name: AppRoute.intro.name,
        builder: (context, state) => const IntroScreen(),
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
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          final id = state.uri.queryParameters['id'] ?? '';
          return RoleSelectionScreen(email: email, id: id);
        },
      ),
      GoRoute(
        path: AppRoute.onboardingDetails.path,
        name: AppRoute.onboardingDetails.name,
        builder: (context, state) {
          // Safely determine role from the provider directly
          final profile = ref.read(userProfileProvider).value;
          final role = profile?.role ?? UserRole.customer;
          return OnboardingDetailsScreen(role: role);
        },
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
                routes: [
                  GoRoute(
                    path: AppRoute.accountDetails.path,
                    name: AppRoute.accountDetails.name,
                    builder: (context, state) => const AccountDetailsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.listen(
    authStateProvider,
    (_, _) => router.refresh(),
  );

  ref.listen(
    userProfileProvider,
    (_, _) => router.refresh(),
  );

  return router;
});

