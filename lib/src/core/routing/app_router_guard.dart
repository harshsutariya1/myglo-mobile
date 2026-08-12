import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/shared/authentication/models/auth_repository.dart';
import '../../features/shared/authentication/controllers/user_profile_provider.dart';
import 'app_router.dart';

/// Handles the redirection logic for the application based on authentication
/// and onboarding state.
String? appRouterRedirect(BuildContext context, GoRouterState state, Ref ref) {
  final authState = ref.read(authStateProvider);
  final userProfileState = ref.read(userProfileProvider);

  if (authState.hasError || userProfileState.hasError) {
    // If there's a fatal error in providers, redirect to error screen
    if (state.uri.path != AppRoute.error.path) {
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
    if (userProfileState.isLoading) {
      return AppRoute.splash.path;
    }
    if (state.uri.path != AppRoute.roleSelection.path) {
      return '${AppRoute.roleSelection.path}?email=${session.user.email}&id=${session.user.id}';
    }
    return null;
  }

  // 2. In all_users but missing details -> Onboarding
  if (profile.profile.firstName == null ||
      profile.profile.firstName!.isEmpty ||
      profile.profile.lastName == null ||
      profile.profile.lastName!.isEmpty) {
    if (state.uri.path != AppRoute.onboardingDetails.path) {
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
  ];

  final providerRoutes = [
    AppRoute.providerHome.path,
    AppRoute.businessTools.path,
    AppRoute.providerProfile.path,
    AppRoute.settings.path, // Assuming settings are provider specific for now
  ];

  if (isCustomer && providerRoutes.any((route) => currentPath.startsWith(route))) {
    return AppRoute.customerHome.path;
  }

  if (isProvider && customerRoutes.any((route) => currentPath.startsWith(route))) {
    return AppRoute.providerHome.path;
  }

  // 4. Fully onboarded -> Redirect to home if on auth screens
  if (isAuthRouteOrSplash) {
    return isProvider ? AppRoute.providerHome.path : AppRoute.customerHome.path;
  }

  return null;
}
