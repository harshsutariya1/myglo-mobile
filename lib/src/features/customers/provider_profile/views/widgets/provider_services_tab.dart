import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../providers/provider_profiles/controllers/provider_services_controller.dart';
import '../../../../providers/provider_profiles/models/service_model.dart';
import '../../../../shared/services/views/widgets/service_tile.dart';
import 'section_states.dart';

/// Label for services saved without a category.
const String uncategorisedServicesLabel = 'Other Services';

/// Groups [services] by category, keeping the order in which each category
/// first appears. Services without a category go under
/// [uncategorisedServicesLabel].
Map<String, List<ServiceModel>> groupServicesByCategory(List<ServiceModel> services) {
  final grouped = <String, List<ServiceModel>>{};
  for (final service in services) {
    final category = service.category?.trim() ?? '';
    grouped
        .putIfAbsent(category.isNotEmpty ? category : uncategorisedServicesLabel, () => [])
        .add(service);
  }
  return grouped;
}

/// Services tab of the public provider profile, as slivers.
class ProviderServicesTab extends ConsumerWidget {
  const ProviderServicesTab({
    super.key,
    required this.providerId,
    required this.onOpen,
    required this.onBook,
  });

  final String providerId;

  /// Tapping a service: show its details.
  final ValueChanged<ServiceModel> onOpen;

  /// The "+" on a service: start booking with it selected.
  final ValueChanged<ServiceModel> onBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(providerServicesProvider(providerId));

    return servicesAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: ServiceListSkeleton(showAction: true),
      ),
      error: (error, _) => SliverToBoxAdapter(
        child: SectionErrorView(
          title: "Services didn't load",
          message: describeLoadError(error, subject: 'these services'),
          onRetry: () => ref.invalidate(providerServicesProvider(providerId)),
        ),
      ),
      data: (services) {
        if (services.isEmpty) {
          return const SliverToBoxAdapter(
            child: SectionEmptyView(
              icon: Icons.content_cut_rounded,
              title: 'No services listed yet',
              message: "This provider hasn't published any services. Check back soon.",
            ),
          );
        }

        final rows = <Widget>[];
        for (final entry in groupServicesByCategory(services).entries) {
          rows.add(_CategoryHeading(entry.key));
          for (final service in entry.value) {
            rows.add(ServiceTile(
              service: service,
              onTap: () => onOpen(service),
              trailing: ServiceAddButton(serviceName: service.name, onPressed: () => onBook(service)),
            ));
          }
        }
        return SliverList.list(children: rows);
      },
    );
  }
}

class _CategoryHeading extends StatelessWidget {
  const _CategoryHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
