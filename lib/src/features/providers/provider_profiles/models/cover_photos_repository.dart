import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../shared/authentication/models/auth_repository.dart';

final coverPhotosRepositoryProvider = Provider<CoverPhotosRepository>((ref) {
  return CoverPhotosRepository(ref.watch(supabaseClientProvider));
});

/// A provider's cover photos: image files in the public `cover-photos`
/// bucket (under the provider's own folder) and their order on
/// `profiles.cover_photos`. Storage policies and a database trigger keep
/// each provider to their own folder and at most five photos.
class CoverPhotosRepository {
  CoverPhotosRepository(this._client);

  final SupabaseClient _client;

  static const String bucket = 'cover-photos';
  static const _tag = 'CoverPhotosRepository';
  static const _uuid = Uuid();

  /// Compresses [file] and uploads it, returning its public URL. The photo
  /// isn't on the profile until [save] includes it.
  Future<String> upload(String userId, File file) async {
    final tempDir = await getTemporaryDirectory();
    final target = '${tempDir.path}/${_uuid.v4()}.jpg';
    // Long edge capped around 2.5k px: sharp on any phone, a few hundred KB.
    final compressed = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      target,
      quality: 80,
      minWidth: 1920,
      minHeight: 1920,
      format: CompressFormat.jpeg,
    );
    if (compressed == null) {
      AppLogger.e('Failed to compress a cover photo', tag: _tag);
      throw const CoverPhotoException("That photo couldn't be processed. Try a different one.");
    }

    final path = '$userId/${_uuid.v4()}.jpg';
    final sw = Stopwatch()..start();
    try {
      await _client.storage.from(bucket).upload(
            path,
            File(compressed.path),
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false, cacheControl: '31536000'),
          );
      sw.stop();
      AppLogger.api('storage.upload $bucket', endpoint: path, duration: sw.elapsed);
      return _client.storage.from(bucket).getPublicUrl(path);
    } catch (e, st) {
      AppLogger.e('Failed to upload a cover photo', tag: _tag, error: e, stackTrace: st);
      rethrow;
    } finally {
      try {
        await File(compressed.path).delete();
      } catch (_) {
        // Temp file; the OS clears the cache directory eventually.
      }
    }
  }

  /// Puts exactly [urls], in this order, on the provider's profile.
  Future<void> save(String userId, List<String> urls) async {
    assert(urls.length <= AppConfig.coverPhotosMax);
    final sw = Stopwatch()..start();
    try {
      await _client.from('profiles').update({'cover_photos': urls}).eq('id', userId);
      sw.stop();
      AppLogger.api('profiles.update(cover_photos)', count: urls.length, duration: sw.elapsed);
    } catch (e, st) {
      AppLogger.e('Failed to save cover photos', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Deletes the files behind [urls]. Best effort: a leftover file only
  /// costs storage, and [removeUnused] tidies it up later.
  Future<void> deleteFiles(Iterable<String> urls) async {
    final paths = urls.map(storagePath).whereType<String>().toList();
    if (paths.isEmpty) return;
    try {
      await _client.storage.from(bucket).remove(paths);
    } catch (e, st) {
      AppLogger.w('Failed to delete cover photo files', tag: _tag, error: e, stackTrace: st);
    }
  }

  /// Deletes files in the provider's folder that aren't on their profile,
  /// e.g. left behind by an upload that was interrupted.
  Future<void> removeUnused(String userId, List<String> keep) async {
    try {
      final files = await _client.storage.from(bucket).list(path: userId);
      final kept = keep.map(storagePath).whereType<String>().toSet();
      final unused = [
        for (final file in files)
          if (file.id != null && !kept.contains('$userId/${file.name}')) '$userId/${file.name}',
      ];
      if (unused.isNotEmpty) await _client.storage.from(bucket).remove(unused);
    } catch (e, st) {
      AppLogger.w('Tidying unused cover photos failed', tag: _tag, error: e, stackTrace: st);
    }
  }

  /// `<uid>/<file>.jpg` from a public object URL, or null for anything else.
  static String? storagePath(String url) {
    const marker = '/storage/v1/object/public/$bucket/';
    final index = url.indexOf(marker);
    if (index < 0) return null;
    final path = url.substring(index + marker.length).split('?').first;
    return path.isEmpty ? null : Uri.decodeComponent(path);
  }
}

/// A cover photo problem with a message ready to show.
class CoverPhotoException implements Exception {
  const CoverPhotoException(this.message);

  final String message;

  @override
  String toString() => 'CoverPhotoException: $message';
}
