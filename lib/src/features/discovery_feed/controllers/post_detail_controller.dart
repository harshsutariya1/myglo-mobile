import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/authentication/models/profile_model.dart';
import '../../shared/authentication/models/user_repository.dart';
import '../models/post_model.dart';
import '../models/post_repository.dart';

/// Public (masked) profile of a post's author or tagged provider. `null` when
/// the account no longer exists.
final postProfileProvider = FutureProvider.autoDispose.family<ProfileModel?, String>((ref, userId) {
  return ref.watch(userRepositoryProvider).getPublicProfile(userId);
});

/// One post by id, for shared links. `null` when it was deleted or isn't
/// visible to the viewer.
final postByIdProvider = FutureProvider.autoDispose.family<PostModel?, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).getPost(postId);
});
