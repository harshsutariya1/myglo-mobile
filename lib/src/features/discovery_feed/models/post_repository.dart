import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../../providers/provider_profiles/models/service_model.dart';
import '../../shared/authentication/models/auth_repository.dart';
import 'post_model.dart';

class ProviderSearchResult {
  final String id;
  final String providerName;
  final String? profilePic;

  ProviderSearchResult({
    required this.id,
    required this.providerName,
    this.profilePic,
  });

  factory ProviderSearchResult.fromJson(Map<String, dynamic> json) {
    return ProviderSearchResult(
      id: json['id'] as String,
      providerName: json['provider_name'] as String,
      profilePic: json['profile_pic'] as String?,
    );
  }
}

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository(ref.watch(supabaseClientProvider));
});

/// Postgres `unique_violation` SQLSTATE.
const _uniqueViolation = '23505';

class PostRepository {
  final SupabaseClient _client;
  final _uuid = const Uuid();

  PostRepository(this._client);

  Future<String> uploadPostMedia(String userId, File file) async {
    AppLogger.d('Compressing post media for user $userId...', tag: 'PostRepository');
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/${_uuid.v4()}.jpg';
    
    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,
      minWidth: 1024,
      minHeight: 1024,
    );

    if (compressedFile == null) {
      AppLogger.e('Failed to compress post media', tag: 'PostRepository');
      throw Exception('Failed to compress image');
    }

    final path = '$userId/${_uuid.v4()}.jpg';
    AppLogger.d('Uploading post image to storage: $path', tag: 'PostRepository');
    final sw = Stopwatch()..start();
    try {
      await _client.storage.from('post-media').upload(
            path,
            File(compressedFile.path),
            fileOptions: const FileOptions(upsert: false),
          );
      sw.stop();
      final baseUrl = _client.storage.from('post-media').getPublicUrl(path);
      AppLogger.api('storage.upload post-media', endpoint: path, duration: sw.elapsed);
      return baseUrl;
    } catch (e, st) {
      AppLogger.e('Failed to upload post image to storage', tag: 'PostRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Creates a post. Pass the same [id] when re-submitting after a failure
  /// (e.g. a connection drop mid-request): if the first attempt already reached
  /// the database, the retry is treated as success instead of duplicating it.
  Future<void> createPost({
    required String id,
    required String authorId,
    required List<String> mediaUrls,
    String? caption,
    String? serviceId,
    String? taggedProviderId,
  }) async {
    AppLogger.d(
      'Creating post for author $authorId (media count: ${mediaUrls.length})',
      tag: 'PostRepository',
    );
    final sw = Stopwatch()..start();
    try {
      await _client.from('posts').insert({
        'id': id,
        'author_id': authorId,
        'media_urls': mediaUrls,
        'caption': caption,
        'service_id': serviceId,
        'tagged_provider_id': taggedProviderId,
      });
      sw.stop();
      AppLogger.api('posts.insert', duration: sw.elapsed);
    } on PostgrestException catch (e) {
      if (e.code == _uniqueViolation) {
        AppLogger.w('Post $id already exists; treating retry as success', tag: 'PostRepository');
        return;
      }
      AppLogger.e('Failed to create post record', tag: 'PostRepository', error: e);
      rethrow;
    } catch (e, st) {
      AppLogger.e('Failed to create post record', tag: 'PostRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<ProviderSearchResult>> searchProviders(String query) async {
    if (query.isEmpty) return [];
    
    AppLogger.d('Searching providers with query: "$query"', tag: 'PostRepository');
    final sw = Stopwatch()..start();
    try {
      final response = await _client
          .from('public_profiles')
          .select('id, provider_name, profile_pic')
          .eq('role', 'provider')
          .ilike('provider_name', '%$query%')
          .limit(10);
      sw.stop();
      final results = (response as List).map((e) => ProviderSearchResult.fromJson(e)).toList();
      AppLogger.api('public_profiles.search', count: results.length, duration: sw.elapsed);
      return results;
    } catch (e, st) {
      AppLogger.e('Failed to search providers', tag: 'PostRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<ServiceModel>> getProviderServices(String providerId) async {
    AppLogger.d('Fetching services for provider: $providerId', tag: 'PostRepository');
    final sw = Stopwatch()..start();
    try {
      final response = await _client
          .from('services')
          .select()
          .eq('provider_id', providerId)
          .order('created_at');
      sw.stop();
      final services = (response as List).map((e) => ServiceModel.fromJson(e)).toList();
      AppLogger.api('services.select', count: services.length, duration: sw.elapsed);
      return services;
    } catch (e, st) {
      AppLogger.e('Failed to get provider services', tag: 'PostRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<PostModel>> getUserPosts(String userId) async {
    AppLogger.d('Fetching user posts for author: $userId', tag: 'PostRepository');
    final sw = Stopwatch()..start();
    try {
      final response = await _client
          .from('posts')
          .select()
          .eq('author_id', userId)
          .order('created_at', ascending: false);
      sw.stop();
      final posts = (response as List).map((e) => PostModel.fromJson(e)).toList();
      AppLogger.api('posts.select(user)', count: posts.length, duration: sw.elapsed);
      return posts;
    } catch (e, st) {
      AppLogger.e('Failed to fetch user posts', tag: 'PostRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<PostModel>> getAllPosts() async {
    AppLogger.d('Fetching all feed posts...', tag: 'PostRepository');
    final sw = Stopwatch()..start();
    try {
      final response = await _client
          .from('posts')
          .select()
          .order('created_at', ascending: false);
      sw.stop();
      final posts = (response as List).map((e) => PostModel.fromJson(e)).toList();
      AppLogger.api('posts.select(all)', count: posts.length, duration: sw.elapsed);
      return posts;
    } catch (e, st) {
      AppLogger.e('Failed to fetch feed posts', tag: 'PostRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deletePost(String postId, List<String> mediaUrls) async {
    AppLogger.d('Deleting post: $postId (media count: ${mediaUrls.length})', tag: 'PostRepository');
    final sw = Stopwatch()..start();
    try {
      // 1. Delete associated media from Storage
      if (mediaUrls.isNotEmpty) {
        final pathsToDelete = mediaUrls.map((url) {
          final parts = url.split('/post-media/');
          if (parts.length > 1) {
            return parts.last;
          }
          return '';
        }).where((path) => path.isNotEmpty).toList();

        if (pathsToDelete.isNotEmpty) {
          AppLogger.d('Removing media paths from storage: $pathsToDelete', tag: 'PostRepository');
          await _client.storage.from('post-media').remove(pathsToDelete);
        }
      }

      // 2. Delete the post record from Database
      await _client.from('posts').delete().eq('id', postId);
      sw.stop();
      AppLogger.api('posts.delete', endpoint: 'id=$postId', duration: sw.elapsed);
      AppLogger.i('Post $postId deleted successfully', tag: 'PostRepository');
    } catch (e, st) {
      AppLogger.e('Failed to delete post $postId', tag: 'PostRepository', error: e, stackTrace: st);
      rethrow;
    }
  }
}
