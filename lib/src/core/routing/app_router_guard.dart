import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/shared/authentication/models/auth_repository.dart';
import '../../features/shared/authentication/controllers/user_profile_provider.dart';
import '../services/app_preferences.dart';
import '../utils/app_logger.dart';
import 'app_router.dart';

/// Path prefix shared by every `/provider/:id` location. The trailing slash
/// keeps it from matching the provider's own `/provider_profile` tab.
const publicProviderProfilePrefix = '/provider/';

/// Client booking pages (`/booking/:id`, `/booking-confirmed/:id`). The first
/// has a trailing slash so it doesn't match the `/bookings` tab.
const clientBookingPrefixes = ['/booking/', '/booking-confirmed/'];

/// Provider-only pages: appointments, availability and business profile
/// editors. `/business/` has a trailing slash so it doesn't match the
/// `/business_tools` tab.
const providerOnlyPrefixes = ['/appointments/', '/schedule/', '/business/'];

/// Client-only discovery pages: search and the map.
const clientDiscoveryPaths = ['/search', '/map'];

/// Whether only clients may open [path].
bool isClientOnlyPath(String path) => [
      AppRoute.customerHome.path,
      AppRoute.bookings.path,
      AppRoute.customerProfile.path,
      // Client view of a provider (`/provider/:id`), which includes booking.
      publicProviderProfilePrefix,
      ...clientBookingPrefixes,
      ...clientDiscoveryPaths,
    ].any(path.startsWith);

/// Whether only providers may open [path].
bool isProviderOnlyPath(String path) => [
      AppRoute.providerHome.path,
      AppRoute.businessTools.path,
      AppRoute.providerProfile.path,
      AppRoute.settings.path,
      ...providerOnlyPrefixes,
    ].any(path.startsWith);

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

  // Signed out: the intro slides the first time on this device, sign-in
  // after that (e.g. after logging out).
  if (!isAuth) {
    final introSeen = ref.read(introSeenProvider);
    if (introSeen && state.uri.path == AppRoute.intro.path) {
      return AppRoute.auth.path;
    }
    if (!isUnauthRoute) {
      final target = introSeen ? AppRoute.auth.path : AppRoute.intro.path;
      AppLogger.d(
        'Unauthenticated access to "${state.uri.path}". Redirecting to $target',
        tag: 'RouterGuard',
      );
      return target;
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

  if (isCustomer && isProviderOnlyPath(currentPath)) {
    AppLogger.d(
      'Customer attempted provider route ($currentPath). Rerouting to ${AppRoute.customerHome.path}',
      tag: 'RouterGuard',
    );
    return AppRoute.customerHome.path;
  }

  if (isProvider && isClientOnlyPath(currentPath)) {
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
