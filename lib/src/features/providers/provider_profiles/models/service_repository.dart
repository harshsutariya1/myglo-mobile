import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/utils/app_logger.dart';
import 'service_model.dart';

final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  return ServiceRepository(Supabase.instance.client);
});

/// Postgres `unique_violation` SQLSTATE.
const _uniqueViolation = '23505';

const _imageBucket = 'service-images';

/// Storage path of a `service-images` public URL (cache-busting query
/// dropped), or `null` if [url] isn't in that bucket.
String? serviceImagePathFromUrl(String? url) {
  if (url == null) return null;
  const marker = '/$_imageBucket/';
  final start = url.indexOf(marker);
  if (start < 0) return null;
  final path = Uri.decodeComponent(url.substring(start + marker.length).split('?').first);
  return path.isEmpty ? null : path;
}

class ServiceRepository {
  final SupabaseClient _client;
  final _uuid = const Uuid();

  ServiceRepository(this._client);

  /// Creates a service. Pass the same [id] when re-submitting after a failure
  /// (e.g. a connection drop mid-request): if the first attempt actually reached
  /// the database, the retry returns that row instead of inserting a duplicate.
  Future<ServiceModel> createService({
    String? id,
    required String providerId,
    required String name,
    required String description,
    required double price,
    required int durationMinutes,
    String? category,
    String? imageUrl,
  }) async {
    final serviceId = id ?? _uuid.v4();
    final newService = {
      'id': serviceId,
      'provider_id': providerId,
      'name': name,
      'description': description,
      'price': price,
      'duration_minutes': durationMinutes,
      'category': category,
      'image_url': imageUrl,
    };

    AppLogger.d('Creating service "$name" for provider $providerId', tag: 'ServiceRepository');
    final sw = Stopwatch()..start();
    try {
      final response = await _client
          .from('services')
          .insert(newService)
          .select()
          .single();
      sw.stop();
      final model = ServiceModel.fromJson(response);
      AppLogger.api('services.insert', endpoint: 'id=$serviceId', duration: sw.elapsed);
      AppLogger.i('Service "$name" ($serviceId) created successfully', tag: 'ServiceRepository');
      return model;
    } on PostgrestException catch (e) {
      if (e.code != _uniqueViolation) {
        AppLogger.e('Failed to create service "$name"', tag: 'ServiceRepository', error: e);
        rethrow;
      }
      // Same client id already stored: an earlier attempt succeeded but its
      // response was lost. Return the existing row.
      AppLogger.w('Service $serviceId already exists; treating retry as success', tag: 'ServiceRepository');
      final existing = await _client.from('services').select().eq('id', serviceId).single();
      return ServiceModel.fromJson(existing);
    } catch (e, st) {
      AppLogger.e('Failed to create service "$name"', tag: 'ServiceRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<ServiceModel>> getServices(String providerId) async {
    AppLogger.d('Fetching services for provider: $providerId', tag: 'ServiceRepository');
    final sw = Stopwatch()..start();
    try {
      final response = await _client
          .from('services')
          .select()
          .eq('provider_id', providerId)
          .order('created_at', ascending: false);
      sw.stop();
      final list = (response as List<dynamic>)
          .map((json) => ServiceModel.fromJson(json as Map<String, dynamic>))
          .toList();
      AppLogger.api('services.select', count: list.length, duration: sw.elapsed);
      return list;
    } catch (e, st) {
      AppLogger.e('Failed to fetch services for provider $providerId', tag: 'ServiceRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// A single service, or `null` if it doesn't exist (or was deleted).
  Future<ServiceModel?> getServiceById(String id) async {
    AppLogger.d('Fetching service $id', tag: 'ServiceRepository');
    final sw = Stopwatch()..start();
    try {
      final response = await _client.from('services').select().eq('id', id).maybeSingle();
      sw.stop();
      AppLogger.api('services.select(single)', endpoint: 'id=$id', duration: sw.elapsed);
      return response == null ? null : ServiceModel.fromJson(response);
    } catch (e, st) {
      AppLogger.e('Failed to fetch service $id', tag: 'ServiceRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Updates the editable fields of a service. RLS limits this to the owner.
  Future<ServiceModel> updateService({
    required String id,
    required String name,
    required String description,
    required double price,
    required int durationMinutes,
    String? category,
    String? imageUrl,
  }) async {
    AppLogger.d('Updating service $id', tag: 'ServiceRepository');
    final sw = Stopwatch()..start();
    try {
      final response = await _client
          .from('services')
          .update({
            'name': name,
            'description': description,
            'price': price,
            'duration_minutes': durationMinutes,
            'category': category,
            'image_url': imageUrl,
          })
          .eq('id', id)
          .select()
          .single();
      sw.stop();
      AppLogger.api('services.update', endpoint: 'id=$id', duration: sw.elapsed);
      return ServiceModel.fromJson(response);
    } catch (e, st) {
      AppLogger.e('Failed to update service $id', tag: 'ServiceRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Deletes [service] and, when no other service still shows it, its image.
  ///
  /// Posts linked to the service keep existing; the foreign key sets their
  /// `service_id` to null.
  Future<void> deleteService(ServiceModel service) async {
    AppLogger.d('Deleting service ${service.id}', tag: 'ServiceRepository');
    final sw = Stopwatch()..start();
    try {
      await _client.from('services').delete().eq('id', service.id);
      sw.stop();
      AppLogger.api('services.delete', endpoint: 'id=${service.id}', duration: sw.elapsed);
    } catch (e, st) {
      AppLogger.e('Failed to delete service ${service.id}', tag: 'ServiceRepository', error: e, stackTrace: st);
      rethrow;
    }
    await removeImageIfUnused(service.imageUrl);
  }

  /// Removes the stored image behind [imageUrl] unless a service still uses
  /// it (duplicated services share their original's image).
  ///
  /// Best effort: a leftover file is harmless, so failures are logged rather
  /// than thrown.
  Future<void> removeImageIfUnused(String? imageUrl) async {
    final path = serviceImagePathFromUrl(imageUrl);
    if (path == null) return;
    try {
      final stillUsed = await _client
          .from('services')
          .select('id')
          .like('image_url', '%/$_imageBucket/$path%')
          .limit(1);
      if ((stillUsed as List).isNotEmpty) {
        AppLogger.d('Service image $path still in use; keeping it', tag: 'ServiceRepository');
        return;
      }
    } catch (e, st) {
      AppLogger.w('Could not check usage of service image $path; keeping it',
          tag: 'ServiceRepository', error: e, stackTrace: st);
      return;
    }
    await deleteServiceImage(path);
  }

  Future<String> uploadServiceImage(String imagePath, File imageFile) async {
    AppLogger.d('Compressing service image for $imagePath...', tag: 'ServiceRepository');
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/${const Uuid().v4()}.jpg';
    
    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      imageFile.absolute.path,
      targetPath,
      quality: 70,
      minWidth: 800,
      minHeight: 800,
    );

    if (compressedFile == null) {
      AppLogger.e('Failed to compress service image', tag: 'ServiceRepository');
      throw Exception('Failed to compress service image');
    }

    AppLogger.d('Uploading service image to storage: $imagePath', tag: 'ServiceRepository');
    final sw = Stopwatch()..start();
    try {
      await _client.storage
          .from(_imageBucket)
          .upload(imagePath, File(compressedFile.path), fileOptions: const FileOptions(upsert: true));
      sw.stop();
      final baseUrl = _client.storage.from(_imageBucket).getPublicUrl(imagePath);
      final finalUrl = '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      AppLogger.api('storage.upload service-images', endpoint: imagePath, duration: sw.elapsed);
      return finalUrl;
    } catch (e, st) {
      AppLogger.e('Failed to upload service image to storage', tag: 'ServiceRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteServiceImage(String imagePath) async {
    AppLogger.d('Deleting service image from storage: $imagePath', tag: 'ServiceRepository');
    try {
      await _client.storage.from(_imageBucket).remove([imagePath]);
      AppLogger.d('Service image deleted: $imagePath', tag: 'ServiceRepository');
    } catch (e, st) {
      AppLogger.w('Failed to delete service image $imagePath', tag: 'ServiceRepository', error: e, stackTrace: st);
    }
  }
}
