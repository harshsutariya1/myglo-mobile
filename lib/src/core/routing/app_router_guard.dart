import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/data/auth_repository.dart';
import '../../features/authentication/application/user_profile_provider.dart';
import 'app_router.dart';

/// Handles the redirection logic for the application based on authentication
/// and onboarding state.
String? appRouterRedirect(BuildContext context, GoRouterState state, Ref ref) {
  final authState = ref.read(authStateProvider);
  final userProfileState = ref.read(userProfileProvider);

  if (authState.hasError || userProfileState.hasError) {
    // If there's a fatal error in providers, redirect to intro or splash
    return AppRoute.intro.path;
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
}
