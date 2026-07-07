import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'service_model.dart';

final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  return ServiceRepository(Supabase.instance.client);
});

class ServiceRepository {
  final SupabaseClient _client;
  final _uuid = const Uuid();

  ServiceRepository(this._client);

  Future<ServiceModel> createService({
    required String providerId,
    required String name,
    required String description,
    required double price,
    required int durationMinutes,
    String? category,
    String? imageUrl,
  }) async {
    final id = _uuid.v4();
    final newService = {
      'id': id,
      'provider_id': providerId,
      'name': name,
      'description': description,
      'price': price,
      'duration_minutes': durationMinutes,
      'category': category,
      'image_url': imageUrl,
    };

    final response = await _client
        .from('services')
        .insert(newService)
        .select()
        .single();

    return ServiceModel.fromJson(response);
  }

  Future<List<ServiceModel>> getServices(String providerId) async {
    final response = await _client
        .from('services')
        .select()
        .eq('provider_id', providerId)
        .order('created_at', ascending: false);
        
    return (response as List<dynamic>)
        .map((json) => ServiceModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<String> uploadServiceImage(String imagePath, File imageFile) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/${const Uuid().v4()}.jpg';
    
    var compressedFile = await FlutterImageCompress.compressAndGetFile(
      imageFile.absolute.path,
      targetPath,
      quality: 70,
      minWidth: 800,
      minHeight: 800,
    );

    if (compressedFile == null) {
      throw Exception('Failed to compress service image');
    }

    await _client.storage
        .from('service-images')
        .upload(imagePath, File(compressedFile.path), fileOptions: const FileOptions(upsert: true));
    final baseUrl = _client.storage.from('service-images').getPublicUrl(imagePath);
    return '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> deleteServiceImage(String imagePath) async {
    await _client.storage.from('service-images').remove([imagePath]);
  }
}
