import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post_model.dart';
import '../models/post_repository.dart';

final userPostsProvider = FutureProvider.family<List<PostModel>, String>((ref, userId) async {
  return ref.read(postRepositoryProvider).getUserPosts(userId);
});
