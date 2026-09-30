import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/shared/authentication/models/auth_repository.dart';
import '../../features/shared/authentication/controllers/user_profile_provider.dart';
import '../utils/app_logger.dart';
import 'app_router.dart';

/// Path prefix shared by every `/provider/:id` location. The trailing slash
/// keeps it from matching the provider's own `/provider_profile` tab.
const publicProviderProfilePrefix = '/provider/';

/// Handles the redirection logic for the application based on authentication
/// and onboarding state.
String? appRouterRedirect(BuildContext context, GoRouterState state, Ref ref) {
  final authState = ref.read(authStateProvider);
  final userProfileState = ref.read(userProfileProvider);

  if (authState.hasError || userProfileState.hasError) {
    if (state.uri.path != AppRoute.error.path) {
      AppLogger.w(
        'Provider error detected. Redirecting to ${AppRoute.error.path}',
        tag: 'RouterGuard',
      );
      return AppRoute.error.path;
    }
    return null;
  }

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
    if (!isUnauthRoute) {
      AppLogger.d(
        'Unauthenticated access to "${state.uri.path}". Redirecting to ${AppRoute.intro.path}',
        tag: 'RouterGuard',
      );
      return AppRoute.intro.path;
    }
    return null;
  }

  // If user is authenticated, check their onboarding status
  if (userProfileState.isLoading && !userProfileState.hasValue) {
    return AppRoute.splash.path; // Show splash while loading profile
  }

  final profile = userProfileState.value;

  // 1. Not in all_users table -> Role Selection
  if (profile == null) {
    if (userProfileState.isLoading) {
      return AppRoute.splash.path;
    }
    if (state.uri.path != AppRoute.roleSelection.path) {
      AppLogger.d(
        'User profile missing role. Redirecting to ${AppRoute.roleSelection.path}',
        tag: 'RouterGuard',
      );
      return Uri(
        path: AppRoute.roleSelection.path,
        queryParameters: {
          'email': session.user.email ?? '',
          'id': session.user.id,
        },
      ).toString();
    }
    return null;
  }

  // 2. In all_users but missing details -> Onboarding
  if (profile.profile.firstName == null ||
      profile.profile.firstName!.isEmpty ||
      profile.profile.lastName == null ||
      profile.profile.lastName!.isEmpty) {
    if (state.uri.path != AppRoute.onboardingDetails.path) {
      AppLogger.d(
        'Profile missing name details. Redirecting to ${AppRoute.onboardingDetails.path}',
        tag: 'RouterGuard',
      );
      return AppRoute.onboardingDetails.path;
    }
    return null;
  }

  final isCustomer = profile.isCustomer;
  final isProvider = profile.isProvider;

  // 3. Role-based route guarding
  final currentPath = state.uri.path;

  final customerRoutes = [
    AppRoute.customerHome.path,
    AppRoute.bookings.path,
    AppRoute.customerProfile.path,
    // Client view of a provider (`/provider/:id`), which includes booking.
    publicProviderProfilePrefix,
  ];

  final providerRoutes = [
    AppRoute.providerHome.path,
    AppRoute.businessTools.path,
    AppRoute.providerProfile.path,
    AppRoute.settings.path,
  ];

  if (isCustomer && providerRoutes.any((route) => currentPath.startsWith(route))) {
    AppLogger.d(
      'Customer attempted provider route ($currentPath). Rerouting to ${AppRoute.customerHome.path}',
      tag: 'RouterGuard',
    );
    return AppRoute.customerHome.path;
  }

  if (isProvider && customerRoutes.any((route) => currentPath.startsWith(route))) {
    AppLogger.d(
      'Provider attempted customer route ($currentPath). Rerouting to ${AppRoute.providerHome.path}',
      tag: 'RouterGuard',
    );
    return AppRoute.providerHome.path;
  }

  // 4. Fully onboarded -> Redirect to home if on auth screens
  if (isAuthRouteOrSplash) {
    final target = isProvider ? AppRoute.providerHome.path : AppRoute.customerHome.path;
    AppLogger.d(
      'Authenticated user at "$currentPath". Redirecting to home ($target)',
      tag: 'RouterGuard',
    );
    return target;
  }

  return null;
}
