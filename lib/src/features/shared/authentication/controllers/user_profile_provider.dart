import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/auth_repository.dart';
import '../models/user_repository.dart';
import '../models/user_role.dart';
import '../models/business_model.dart';
import '../models/customer_model.dart';
import '../models/all_user_model.dart';

/// A class that bundles the raw Supabase user, their role, and their specific profile model.
class AppUserProfile {
  final User rawUser;
  final UserRole role;
  final AllUserModel allUser;
  final CustomerModel? customerProfile;
  final BusinessModel? businessProfile;

  AppUserProfile({
    required this.rawUser,
    required this.role,
    required this.allUser,
    this.customerProfile,
    this.businessProfile,
  });

  bool get isCustomer => role == UserRole.customer;
  bool get isBusiness => role == UserRole.business;

  String get displayName {
    String name;
    if (isBusiness) {
      final bName = businessProfile?.businessName?.trim() ?? '';
      final fullName =
          '${businessProfile?.firstName ?? ''} ${businessProfile?.lastName ?? ''}'
              .trim();
      name = bName.isNotEmpty ? bName : fullName;
    } else {
      name =
          '${customerProfile?.firstName ?? ''} ${customerProfile?.lastName ?? ''}'
              .trim();
    }
    return name.isEmpty ? 'Guest User' : name;
  }

  String? get displaySubtitle {
    if (isBusiness) {
      final bName = businessProfile?.businessName?.trim() ?? '';
      final fullName =
          '${businessProfile?.firstName ?? ''} ${businessProfile?.lastName ?? ''}'
              .trim();
      return bName.isNotEmpty ? fullName : null;
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

  final userRepo = ref.watch(userRepositoryProvider);

  // Fetch from all_users first to determine role and get base info
  final allUser = await userRepo.getAllUser(user.id);
  if (allUser == null) {
    try {
      // Verify if the user still exists in Supabase auth.
      // This catches cases where the user was deleted from the database
      // but their local session hasn't expired yet.
      await ref.read(supabaseClientProvider).auth.getUser();
    } on AuthException catch (_) {
      // User is invalid or deleted, sign them out locally
      await ref.read(supabaseClientProvider).auth.signOut();
      return null;
    } catch (_) {
      // Ignore other errors (like network issues) to avoid signing out unnecessarily
    }
    return null; // Not fully onboarded in terms of role
  }

  final role = allUser.role;

  if (role == UserRole.business) {
    final businessProfile = await userRepo.getBusiness(user.id);
    return AppUserProfile(
      rawUser: user,
      role: role,
      allUser: allUser,
      businessProfile: businessProfile,
    );
  } else {
    final customerProfile = await userRepo.getCustomer(user.id);
    return AppUserProfile(
      rawUser: user,
      role: role,
      allUser: allUser,
      customerProfile: customerProfile,
    );
  }
});
