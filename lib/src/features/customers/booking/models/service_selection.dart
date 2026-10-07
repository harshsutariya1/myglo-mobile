import '../../../providers/provider_profiles/models/service_model.dart';

/// The services a client has picked for one booking, resolved against the
/// provider's current service list.
///
/// Totals are summed in whole cents so adding several prices such as `$45.10`
/// never drifts by a fraction of a cent. This is a display estimate only: the
/// amount actually charged (including any platform fee) is computed
/// server-side at checkout.
class ServiceSelection {
  const ServiceSelection._({
    required this.services,
    required this.totalCents,
    required this.totalMinutes,
  });

  /// Resolves [selectedIds] against [available], keeping selection order.
  ///
  /// Ids that no longer match a service (it was removed or the list was
  /// refreshed) are dropped, so the selection never shows or charges for
  /// something the provider no longer offers.
  factory ServiceSelection.resolve({
    required List<ServiceModel> available,
    required List<String> selectedIds,
  }) {
    final byId = {for (final service in available) service.id: service};
    final services = [for (final id in selectedIds) ?byId[id]];
    var cents = 0;
    var minutes = 0;
    for (final service in services) {
      cents += (service.price * 100).round();
      minutes += service.durationMinutes;
    }
    return ServiceSelection._(services: services, totalCents: cents, totalMinutes: minutes);
  }

  static const ServiceSelection empty = ServiceSelection._(services: [], totalCents: 0, totalMinutes: 0);

  /// Selected services, in the order they were picked.
  final List<ServiceModel> services;

  final int totalCents;

  /// Combined length of every selected service, back to back.
  final int totalMinutes;

  double get total => totalCents / 100;

  int get count => services.length;

  bool get isEmpty => services.isEmpty;

  bool get isNotEmpty => services.isNotEmpty;

  /// `1 service` / `3 services`.
  String get countLabel => count == 1 ? '1 service' : '$count services';
}
