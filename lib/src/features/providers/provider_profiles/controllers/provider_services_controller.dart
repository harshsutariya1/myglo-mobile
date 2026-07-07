import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_model.dart';
import '../models/service_repository.dart';

final providerServicesProvider = FutureProvider.family<List<ServiceModel>, String>((ref, providerId) async {
  final repository = ref.watch(serviceRepositoryProvider);
  return await repository.getServices(providerId);
});
