import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/auth_repository.dart';
import '../models/user_repository.dart';
import '../models/user_role.dart';
import '../models/profile_model.dart';

/// A class that bundles the raw Supabase user, their role, and their specific profile model.
class AppUserProfile {
  final User rawUser;
  final UserRole role;
  final ProfileModel profile;

  AppUserProfile({
    required this.rawUser,
    required this.role,
    required this.profile,
  });

  bool get isCustomer => role == UserRole.customer;
  bool get isProvider => role == UserRole.provider;

  String get displayName {
    String name;
    if (isProvider) {
      final pName = profile.providerName?.trim() ?? '';
      final fullName =
          '${profile.firstName ?? ''} ${profile.lastName ?? ''}'.trim();
      name = pName.isNotEmpty ? pName : fullName;
    } else {
      name =
          '${profile.firstName ?? ''} ${profile.lastName ?? ''}'.trim();
    }
    return name.isEmpty ? 'Guest User' : name;
  }

  String? get displaySubtitle {
    if (isProvider) {
      final pName = profile.providerName?.trim() ?? '';
      final fullName =
          '${profile.firstName ?? ''} ${profile.lastName ?? ''}'.trim();
      return pName.isNotEmpty ? fullName : null;
    }
    return null;
  }
}

/// Watches the auth state and retrieves the corresponding user profile data from the database.
final userProfileProvider = FutureProvider<AppUserProfile?>((ref) async {
  final authState = ref.watch(authStateProvider).value;
  final user = authState?.session?.user;

  if (user == null) {
    return null;
  }

  AppLogger.d('userProfileProvider: Resolving profile for user ${user.id}', tag: 'UserProfile');
  final userRepo = ref.watch(userRepositoryProvider);

  // Fetch from profiles first to determine role and get base info
  final profile = await userRepo.getProfile(user.id);
  if (profile == null) {
    AppLogger.d('userProfileProvider: No profile row found yet for user ${user.id}', tag: 'UserProfile');
    try {
      // Verify if the user still exists in Supabase auth.
      // This catches cases where the user was deleted from the database
      // but their local session hasn't expired yet.
      await ref.read(supabaseClientProvider).auth.getUser();
    } on AuthException catch (e) {
      AppLogger.w('userProfileProvider: User session is invalid in Auth. Signing out locally: ${e.message}', tag: 'UserProfile');
      // User is invalid or deleted, sign them out locally
      await ref.read(supabaseClientProvider).auth.signOut();
      return null;
    } catch (e) {
      AppLogger.w('userProfileProvider: Transient error verifying user session: $e', tag: 'UserProfile');
    }
    return null; // Not fully onboarded in terms of role
  }

  AppLogger.i(
    'userProfileProvider: Profile resolved successfully for "${profile.firstName ?? ''} ${profile.lastName ?? ''}" (${profile.role.name})',
    tag: 'UserProfile',
  );

  return AppUserProfile(
    rawUser: user,
    role: profile.role,
    profile: profile,
  );
});
