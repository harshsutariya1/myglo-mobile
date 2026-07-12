import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
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
      profilePic: json['profiles']?['profile_pic'] as String?,
    );
  }
}

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository(ref.watch(supabaseClientProvider));
});

class PostRepository {
  final SupabaseClient _client;
  final _uuid = const Uuid();

  PostRepository(this._client);

  Future<String> uploadPostMedia(String userId, File file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/${_uuid.v4()}.jpg';
    
    var compressedFile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,
      minWidth: 1024,
      minHeight: 1024,
    );

    if (compressedFile == null) {
      throw Exception('Failed to compress image');
    }

    final path = '$userId/${_uuid.v4()}.jpg';
    await _client.storage.from('post-media').upload(
          path,
          File(compressedFile.path),
          fileOptions: const FileOptions(upsert: false),
        );
        
    final baseUrl = _client.storage.from('post-media').getPublicUrl(path);
    return baseUrl;
  }

  Future<void> createPost({
    required String authorId,
    required List<String> mediaUrls,
    String? caption,
    String? serviceId,
    String? taggedProviderId,
  }) async {
    await _client.from('posts').insert({
      'author_id': authorId,
      'media_urls': mediaUrls,
      'caption': caption,
      'service_id': serviceId,
      'tagged_provider_id': taggedProviderId,
    });
  }

  Future<List<ProviderSearchResult>> searchProviders(String query) async {
    if (query.isEmpty) return [];
    
    // Join with profiles to get the profile pic
    final response = await _client
        .from('provider_details')
        .select('id, provider_name, profiles!inner(profile_pic)')
        .ilike('provider_name', '%$query%')
        .limit(10);
        
    return (response as List).map((e) => ProviderSearchResult.fromJson(e)).toList();
  }

  Future<List<ServiceModel>> getProviderServices(String providerId) async {
    final response = await _client
        .from('services')
        .select()
        .eq('provider_id', providerId)
        .order('created_at');
        
    return (response as List).map((e) => ServiceModel.fromJson(e)).toList();
  }

  Future<List<PostModel>> getUserPosts(String userId) async {
    final response = await _client
        .from('posts')
        .select()
        .eq('author_id', userId)
        .order('created_at', ascending: false);

    return (response as List).map((e) => PostModel.fromJson(e)).toList();
  }

  Future<List<PostModel>> getAllPosts() async {
    final response = await _client
        .from('posts')
        .select()
        .order('created_at', ascending: false);

    return (response as List).map((e) => PostModel.fromJson(e)).toList();
  }

  Future<void> deletePost(String postId, List<String> mediaUrls) async {
    // 1. Delete associated media from Storage
    if (mediaUrls.isNotEmpty) {
      final pathsToDelete = mediaUrls.map((url) {
        // Extract the path after the bucket name
        // Example URL: https://[ref].supabase.co/storage/v1/object/public/post-media/[authorId]/[uuid].jpg
        final parts = url.split('/post-media/');
        if (parts.length > 1) {
          return parts.last;
        }
        return '';
      }).where((path) => path.isNotEmpty).toList();

      if (pathsToDelete.isNotEmpty) {
        await _client.storage.from('post-media').remove(pathsToDelete);
      }
    }

    // 2. Delete the post record from Database
    await _client.from('posts').delete().eq('id', postId);
  }
}
