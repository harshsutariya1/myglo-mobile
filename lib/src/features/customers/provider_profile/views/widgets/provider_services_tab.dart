import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../providers/provider_profiles/controllers/provider_services_controller.dart';
import '../../../../providers/provider_profiles/models/service_model.dart';
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
    required this.onBook,
  });

  final String providerId;
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
            rows.add(ServiceTile(service: service, onBook: () => onBook(service)));
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
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

/// One bookable service: thumbnail, name, description, price and duration,
/// with a "Book" action. Geometry matches `ServiceRowSkeleton(showAction: true)`.
class ServiceTile extends StatelessWidget {
  const ServiceTile({super.key, required this.service, required this.onBook});

  final ServiceModel service;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final muted = context.colorScheme.onSurface.withValues(alpha: 0.6);
    final thumbFallback = Container(
      color: context.colorScheme.primary.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Icon(Icons.spa_outlined, color: context.colorScheme.primary),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: service.imageUrl == null
                      ? thumbFallback
                      : CachedNetworkImage(
                          imageUrl: service.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => const Shimmer(child: SkeletonBox(borderRadius: 0)),
                          errorWidget: (_, _, _) => thumbFallback,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                    if (service.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        service.description.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, height: 1.3, color: muted),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      '${Formatters.aud(service.price)}  •  ${Formatters.duration(service.durationMinutes)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.colorScheme.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 64,
                height: 36,
                child: FilledButton.tonal(
                  onPressed: onBook,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: context.colorScheme.primary.withValues(alpha: 0.12),
                    foregroundColor: context.colorScheme.onSurface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  child: Text('Book', semanticsLabel: 'Book ${service.name}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(height: 1, thickness: 1, color: context.colorScheme.onSurface.withValues(alpha: 0.08)),
        ],
      ),
    );
  }
}
