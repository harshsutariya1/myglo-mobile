import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/authentication/models/profile_model.dart';
import '../../../shared/authentication/models/user_repository.dart';
import '../../../shared/authentication/models/user_role.dart';

/// The public (masked) profile of the provider with the given id, as seen by a
/// client.
///
/// Resolves to `null` when no such provider exists, including when the id
/// belongs to a customer, so a stale or hand-typed deep link shows a
/// "not found" state instead of an error that would be retried.
///
/// Services and posts are loaded by their own providers
/// (`providerServicesProvider`, `userPostsProvider`) so each part of the
/// screen can load, fail and retry independently.
final publicProviderProfileProvider =
    FutureProvider.autoDispose.family<ProfileModel?, String>((ref, providerId) async {
  final profile = await ref.watch(userRepositoryProvider).getPublicProfile(providerId);
  if (profile == null || profile.role != UserRole.provider) return null;
  return profile;
});
