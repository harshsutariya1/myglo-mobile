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

  /// Newest approved posts tagged with [serviceId], at most [limit].
  ///
  /// Filtered to approved posts explicitly (not just through row-level
  /// security) so the author of a pending tag sees the same public set as
  /// everyone else.
  Future<List<PostModel>> getServicePosts(String serviceId, {int limit = 12}) async {
    AppLogger.d('Fetching posts for service: $serviceId', tag: 'PostRepository');
    final sw = Stopwatch()..start();
    try {
      final response = await _client
          .from('posts')
          .select()
          .eq('service_id', serviceId)
          .eq('tag_status', 'approved')
          .order('created_at', ascending: false)
          .limit(limit);
      sw.stop();
      final posts = (response as List).map((e) => PostModel.fromJson(e)).toList();
      AppLogger.api('posts.select(service)', count: posts.length, duration: sw.elapsed);
      return posts;
    } catch (e, st) {
      AppLogger.e('Failed to fetch service posts', tag: 'PostRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// One page of the Discover feed, newest first.
  ///
  /// Keyset-paginated on `created_at`: pass the oldest timestamp already shown
  /// as [before] to fetch the next page, so posts published while the viewer
  /// scrolls can't shift the window and repeat or skip items.
  ///
  /// With [providerIds], only posts by those providers or tagging them are
  /// returned. [excludeAuthorId] leaves out one author's posts (the viewer's
  /// own). Row-level security limits other people's posts to approved ones.
  Future<List<PostModel>> getFeedPage({
    required int limit,
    DateTime? before,
    List<String>? providerIds,
    String? excludeAuthorId,
  }) async {
    AppLogger.d(
      'Fetching feed page (limit: $limit, before: $before, providers: ${providerIds?.length ?? 'all'})',
      tag: 'PostRepository',
    );
    final sw = Stopwatch()..start();
    try {
      var query = _client.from('posts').select();
      if (providerIds != null) {
        final ids = providerIds.join(',');
        query = query.or('author_id.in.($ids),tagged_provider_id.in.($ids)');
      }
      if (excludeAuthorId != null) query = query.neq('author_id', excludeAuthorId);
      if (before != null) query = query.lt('created_at', before.toUtc().toIso8601String());
      final response = await query.order('created_at', ascending: false).limit(limit);
      sw.stop();
      final posts = (response as List).map((e) => PostModel.fromJson(e)).toList();
      AppLogger.api('posts.select(feed)', count: posts.length, duration: sw.elapsed);
      return posts;
    } catch (e, st) {
      AppLogger.e('Failed to fetch feed page', tag: 'PostRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// One page of approved posts by other people within [radiusMetres] of the
  /// signed-in user's saved location (see the `nearby_posts` RPC), newest
  /// first and keyset-paginated like [getFeedPage]. Empty when the user has no
  /// saved location.
  Future<List<PostModel>> getNearbyPage({
    required int limit,
    required double radiusMetres,
    DateTime? before,
  }) async {
    AppLogger.d('Fetching nearby posts (limit: $limit, before: $before)', tag: 'PostRepository');
    final sw = Stopwatch()..start();
    try {
      final response = await _client.rpc('nearby_posts', params: {
        'p_radius_m': radiusMetres,
        'p_before': before?.toUtc().toIso8601String(),
        'p_limit': limit,
      });
      sw.stop();
      final posts = (response as List).map((e) => PostModel.fromJson(e)).toList();
      AppLogger.api('rpc.nearby_posts', count: posts.length, duration: sw.elapsed);
      return posts;
    } catch (e, st) {
      AppLogger.e('Failed to fetch nearby posts', tag: 'PostRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Whether [userId] has liked [postId].
  Future<bool> hasLiked({required String postId, required String userId}) async {
    final sw = Stopwatch()..start();
    try {
      final response = await _client
          .from('likes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();
      sw.stop();
      AppLogger.api('likes.select(own)', endpoint: 'post=$postId', duration: sw.elapsed);
      return response != null;
    } catch (e, st) {
      AppLogger.e('Failed to read like state for post $postId', tag: 'PostRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Likes [postId] as [userId]. Liking twice is a no-op (the pair is unique),
  /// so a retried request can't double count. `posts.likes_count` is kept in
  /// step by a database trigger.
  Future<void> likePost({required String postId, required String userId}) async {
    final sw = Stopwatch()..start();
    try {
      await _client.from('likes').insert({'post_id': postId, 'user_id': userId});
      sw.stop();
      AppLogger.api('likes.insert', endpoint: 'post=$postId', duration: sw.elapsed);
    } on PostgrestException catch (e) {
      if (e.code == _uniqueViolation) return;
      AppLogger.e('Failed to like post $postId', tag: 'PostRepository', error: e);
      rethrow;
    } catch (e, st) {
      AppLogger.e('Failed to like post $postId', tag: 'PostRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Removes [userId]'s like from [postId], if any.
  Future<void> unlikePost({required String postId, required String userId}) async {
    final sw = Stopwatch()..start();
    try {
      await _client.from('likes').delete().eq('post_id', postId).eq('user_id', userId);
      sw.stop();
      AppLogger.api('likes.delete', endpoint: 'post=$postId', duration: sw.elapsed);
    } catch (e, st) {
      AppLogger.e('Failed to unlike post $postId', tag: 'PostRepository', error: e, stackTrace: st);
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
