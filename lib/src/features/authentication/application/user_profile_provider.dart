import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository.dart';
import '../data/user_repository.dart';
import '../domain/user_role.dart';
import '../domain/business_model.dart';
import '../domain/customer_model.dart';
import '../domain/all_user_model.dart';

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
