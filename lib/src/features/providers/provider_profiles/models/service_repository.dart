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
          .from('service-images')
          .upload(imagePath, File(compressedFile.path), fileOptions: const FileOptions(upsert: true));
      sw.stop();
      final baseUrl = _client.storage.from('service-images').getPublicUrl(imagePath);
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
      await _client.storage.from('service-images').remove([imagePath]);
      AppLogger.d('Service image deleted: $imagePath', tag: 'ServiceRepository');
    } catch (e, st) {
      AppLogger.w('Failed to delete service image $imagePath', tag: 'ServiceRepository', error: e, stackTrace: st);
    }
  }
}
