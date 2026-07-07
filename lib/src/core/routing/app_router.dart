import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/shared/authentication/models/auth_repository.dart';
import '../../features/shared/authentication/views/screens/email_auth_screen.dart';
import '../../features/shared/authentication/views/screens/email_confirmation_screen.dart';
import '../../features/shared/authentication/views/screens/role_selection_screen.dart';
import '../../features/shared/authentication/views/screens/onboarding_details_screen.dart';
import '../../features/shared/authentication/models/user_role.dart';
import '../../features/shared/authentication/views/screens/splash_screen.dart';
import '../../features/shared/authentication/views/screens/intro_screen.dart';

import '../../features/customers/home/views/home_screen.dart';
import '../../features/providers/home/views/provider_home_screen.dart';
import '../../features/customers/bookings/views/bookings_screen.dart';
import '../../features/providers/business_tools/views/business_tools_screen.dart';
import '../../features/customers/customer_profile/views/customer_profile_screen.dart';
import '../../features/providers/provider_profiles/views/screens/profile_screen.dart';
import '../../features/providers/provider_profiles/views/screens/settings_screen.dart';
import '../../features/providers/provider_profiles/views/screens/account_details_screen.dart';

import '../../features/shared/authentication/controllers/user_profile_provider.dart';
import '../widgets/main_scaffold.dart';
import 'app_router_guard.dart';

/// Defines all the route names and paths in the app.
enum AppRoute {
  splash(path: '/'),
  intro(path: '/intro'),
  auth(path: '/auth'),
  confirmEmail(path: '/confirm_email'),
  roleSelection(path: '/role'),
  onboardingDetails(path: '/onboarding_details'),
  customerHome(path: '/customer_home'),
  providerHome(path: '/provider_home'),
  discover(path: '/discover'),
  bookings(path: '/bookings'),
  businessTools(path: '/business_tools'),
  customerProfile(path: '/customer_profile'),
  providerProfile(path: '/provider_profile'),
  settings(path: 'settings'),
  accountDetails(path: 'account-details');

  final String path;
  const AppRoute({required this.path});
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoute.splash.path,
    redirect: (context, state) => appRouterRedirect(context, state, ref),
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
          return EmailConfirmationScreen(
            email: extra['email'] as String? ?? '',
          );
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
            path: AppRoute.customerHome.path,
            name: AppRoute.customerHome.name,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoute.providerHome.path,
            name: AppRoute.providerHome.name,
            builder: (context, state) => const ProviderHomeScreen(),
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
            builder: (context, state) => const BookingsScreen(),
          ),
          GoRoute(
            path: AppRoute.businessTools.path,
            name: AppRoute.businessTools.name,
            builder: (context, state) => const BusinessToolsScreen(),
          ),
          GoRoute(
            path: AppRoute.customerProfile.path,
            name: AppRoute.customerProfile.name,
            builder: (context, state) => const CustomerProfileScreen(),
          ),
          GoRoute(
            path: AppRoute.providerProfile.path,
            name: AppRoute.providerProfile.name,
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

  ref.listen(authStateProvider, (_, _) => router.refresh());
  ref.listen(userProfileProvider, (_, _) => router.refresh());

  return router;
});
