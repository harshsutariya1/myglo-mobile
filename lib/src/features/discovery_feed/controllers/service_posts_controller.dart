import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post_model.dart';
import '../models/post_repository.dart';

/// Recent approved posts tagged with a service, newest first, for showcasing
/// that service's work.
final servicePostsProvider = FutureProvider.autoDispose.family<List<PostModel>, String>((ref, serviceId) {
  return ref.watch(postRepositoryProvider).getServicePosts(serviceId);
});
