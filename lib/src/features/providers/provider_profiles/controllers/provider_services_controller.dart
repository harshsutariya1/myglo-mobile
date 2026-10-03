import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/service_model.dart';
import '../models/service_repository.dart';

final providerServicesProvider = FutureProvider.family<List<ServiceModel>, String>((ref, providerId) async {
  final repository = ref.watch(serviceRepositoryProvider);
  return await repository.getServices(providerId);
});

/// A single service by id, e.g. the one linked to a post. Resolves to `null`
/// when the service has since been deleted.
final serviceByIdProvider = FutureProvider.autoDispose.family<ServiceModel?, String>((ref, serviceId) {
  return ref.watch(serviceRepositoryProvider).getServiceById(serviceId);
});

/// One-shot owner actions on an existing service (the add/edit form has its
/// own controller).
final serviceActionsProvider = Provider<ServiceActions>(ServiceActions.new);

class ServiceActions {
  ServiceActions(this._ref);

  final Ref _ref;

  /// Deletes [service]. Returns whether it succeeded; failures are logged
  /// (and reported) here so callers only need to tell the user.
  Future<bool> delete(ServiceModel service) async {
    try {
      await _ref.read(serviceRepositoryProvider).deleteService(service);
      AppLogger.i('Service ${service.id} deleted', tag: 'ServiceActions');
      _ref.invalidate(providerServicesProvider(service.providerId));
      _ref.invalidate(serviceByIdProvider(service.id));
      return true;
    } catch (e, st) {
      AppLogger.w('Failed to delete service ${service.id}', tag: 'ServiceActions', error: e, stackTrace: st);
      return false;
    }
  }
}
