import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/admin_actions.dart';
import '../controllers/admin_controllers.dart';
import '../models/admin_models.dart';
import '../models/admin_repository.dart';
import 'widgets/admin_widgets.dart';

/// The cities clients can browse: drag to reorder, switch off, edit or add.
class ServiceCitiesScreen extends ConsumerStatefulWidget {
  const ServiceCitiesScreen({super.key});

  @override
  ConsumerState<ServiceCitiesScreen> createState() => _ServiceCitiesScreenState();
}

class _ServiceCitiesScreenState extends ConsumerState<ServiceCitiesScreen> {
  /// The order while a reorder is being saved, so the list doesn't jump.
  List<AdminServiceCity>? _optimistic;

  Future<void> _reorder(List<AdminServiceCity> cities, int from, int to) async {
    final reordered = [...cities];
    final moved = reordered.removeAt(from);
    reordered.insert(to > from ? to - 1 : to, moved);
    setState(() => _optimistic = reordered);
    await runAdminAction(
      context,
      ref,
      action: () => ref.read(adminRepositoryProvider).reorderServiceCities([for (final c in reordered) c.cityId]),
    );
    if (!mounted) return;
    ref.invalidate(adminServiceCitiesProvider);
    await ref.read(adminServiceCitiesProvider.future).catchError((_) => <AdminServiceCity>[]);
    if (mounted) setState(() => _optimistic = null);
  }

  Future<void> _setActive(AdminServiceCity city, bool active) async {
    final reason = await askAdminReason(
      context,
      title: active ? 'Show ${city.name}' : 'Hide ${city.name}',
      summary: active
          ? 'Clients will be able to pick ${city.name} again.'
          : "Clients won't see ${city.name} in the city picker.",
    );
    if (reason == null || !mounted) return;
    await runAdminAction(
      context,
      ref,
      successMessage: active ? '${city.name} is visible' : '${city.name} is hidden',
      action: () => ref.read(adminRepositoryProvider).saveServiceCity(
            cityId: city.cityId,
            name: city.name,
            state: city.state,
            latitude: city.latitude,
            longitude: city.longitude,
            radiusM: city.radiusM,
            isActive: active,
            reason: reason,
          ),
    );
    if (mounted) ref.invalidate(adminServiceCitiesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final cities = ref.watch(adminServiceCitiesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Service cities')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(AppRoute.adminCityEditor.name),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add city'),
      ),
      body: switch (cities) {
        AsyncData(:final value) => () {
            final list = _optimistic ?? value;
            return ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
              itemCount: list.length,
              onReorder: (from, to) => _reorder(list, from, to),
              header: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Clients see active cities in this order. Hold and drag to reorder.',
                  style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
              ),
              itemBuilder: (context, index) {
                final city = list[index];
                return ListTile(
                  key: ValueKey(city.cityId),
                  leading: Icon(Icons.drag_indicator, color: scheme.onSurface.withValues(alpha: 0.4)),
                  title: Text('${city.name}, ${city.state}'),
                  subtitle: Text(
                    '${city.providerCount} ${city.providerCount == 1 ? 'provider' : 'providers'} · '
                    '${(city.radiusM / 1000).toStringAsFixed(0)} km radius',
                  ),
                  trailing: Switch(value: city.isActive, onChanged: (v) => _setActive(city, v)),
                  onTap: () => context.pushNamed(AppRoute.adminCityEditor.name, extra: city),
                );
              },
            );
          }(),
        AsyncError(:final error) =>
          AdminErrorView(error: error, onRetry: () => ref.invalidate(adminServiceCitiesProvider)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
