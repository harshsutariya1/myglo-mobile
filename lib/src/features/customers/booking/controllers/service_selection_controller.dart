import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/provider_profiles/controllers/provider_services_controller.dart';
import '../models/service_selection.dart';

/// Ids of the services the client has picked from one provider, in the order
/// they were picked.
///
/// Scoped to the provider and disposed with the booking screen, so leaving the
/// flow starts the next visit with a clean slate.
final selectedServiceIdsProvider =
    NotifierProvider.autoDispose.family<ServiceSelectionController, List<String>, String>(
  ServiceSelectionController.new,
);

/// The current selection resolved against the provider's loaded services.
///
/// Empty while services are loading or failed to load.
final serviceSelectionProvider = Provider.autoDispose.family<ServiceSelection, String>((ref, providerId) {
  final services = ref.watch(providerServicesProvider(providerId)).value;
  if (services == null) return ServiceSelection.empty;
  return ServiceSelection.resolve(
    available: services,
    selectedIds: ref.watch(selectedServiceIdsProvider(providerId)),
  );
});

class ServiceSelectionController extends Notifier<List<String>> {
  ServiceSelectionController(this.providerId);

  /// The provider whose services are being selected.
  final String providerId;

  @override
  List<String> build() => const [];

  bool isSelected(String serviceId) => state.contains(serviceId);

  /// Adds [serviceId] if it isn't selected, otherwise removes it.
  void toggle(String serviceId) {
    state = isSelected(serviceId) ? _without(serviceId) : [...state, serviceId];
  }

  /// Adds [serviceId] unless it is already selected.
  void select(String serviceId) {
    if (!isSelected(serviceId)) state = [...state, serviceId];
  }

  void remove(String serviceId) {
    if (isSelected(serviceId)) state = _without(serviceId);
  }

  void clear() {
    if (state.isNotEmpty) state = const [];
  }

  List<String> _without(String serviceId) => [
    for (final id in state)
      if (id != serviceId) id,
  ];
}
