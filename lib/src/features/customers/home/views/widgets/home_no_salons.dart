import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../provider_profile/views/widgets/section_states.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/home_location_controller.dart';
import '../../models/service_city.dart';
import 'home_location_picker.dart';

/// Shown when there are no salons where the client is looking: says so, and
/// lists the cities that do have salons so they can switch in one tap.
class HomeNoSalons extends ConsumerWidget {
  const HomeNoSalons({super.key, required this.place});

  final HomePlace? place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final here = place;
    final title = switch (here) {
      NearDevicePlace() => 'No salons near you yet',
      CityPlace(:final city) => 'No salons ${city.placePhrase} yet',
      null => 'No salons yet',
    };
    final currentCityId = here is CityPlace ? here.city.id : null;
    final cities = ref.watch(serviceCitiesProvider);

    Future<void> choose(ServiceCity city) async {
      HapticFeedback.selectionClick();
      await ref.read(homeLocationChoiceProvider.notifier).choose(CityChoice(city.id));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.peach.withValues(alpha: 0.3), AppTheme.primaryPink.withValues(alpha: 0.1)],
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surface,
                  boxShadow: [
                    BoxShadow(color: scheme.primary.withValues(alpha: 0.2), blurRadius: 18, offset: const Offset(0, 6)),
                  ],
                ),
                child: Icon(Icons.storefront_rounded, size: 30, color: scheme.secondary),
              ),
              const SizedBox(height: 14),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: scheme.onSurface),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Myglo is growing city by city. Browse a city where salons are already taking bookings.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.65)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        switch (cities) {
          AsyncData(:final value) => _Suggestions(
              cities: [
                for (final city in value)
                  if (city.hasProviders && city.id != currentCityId) city,
              ],
              onChoose: choose,
            ),
          AsyncError(:final error) => SectionErrorView(
              title: "Couldn't load cities",
              message: describeLoadError(error, subject: 'cities'),
              onRetry: () => ref.invalidate(serviceCitiesProvider),
            ),
          _ => const ServiceCityOptionsSkeleton(count: 2),
        },
      ],
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.cities, required this.onChoose});

  final List<ServiceCity> cities;
  final ValueChanged<ServiceCity> onChoose;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    if (cities.isEmpty) {
      return Text(
        'We’re welcoming new salons every week. Check back soon.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: scheme.onSurface.withValues(alpha: 0.6)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'SALONS ARE LIVE IN',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            color: scheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        for (final city in cities) ...[
          ServiceCityOption(city: city, onTap: () => onChoose(city)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
