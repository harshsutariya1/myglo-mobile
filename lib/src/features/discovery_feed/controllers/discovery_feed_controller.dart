import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post_model.dart';
import '../models/post_repository.dart';

final discoveryFeedProvider = FutureProvider.autoDispose<List<PostModel>>((ref) async {
  return ref.read(postRepositoryProvider).getAllPosts();
});
