import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/location/device_location.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../provider_profile/views/widgets/section_states.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/home_location_controller.dart';
import '../../models/service_city.dart';

/// `21 salons`, `1 salon`.
String salonCountLabel(int count) => '$count ${count == 1 ? 'salon' : 'salons'}';

/// What the home screen is showing right now, for the location button and
/// the picker's tick: the saved choice, or what the feed fell back to.
({bool current, String? cityId}) _activeLocation(WidgetRef ref) {
  final choice = ref.watch(homeLocationChoiceProvider);
  final place = ref.watch(homeFeedProvider.select((feed) => feed.value?.place));
  return switch (choice) {
    CurrentLocationChoice() => (current: true, cityId: null),
    CityChoice(:final cityId) => (current: false, cityId: cityId),
    null => switch (place) {
        NearDevicePlace() => (current: true, cityId: null),
        CityPlace(:final city) => (current: false, cityId: city.id),
        null => (current: false, cityId: null),
      },
  };
}

/// The pill under the greeting: where the home screen is looking, and a way
/// to change it.
class HomeLocationButton extends ConsumerWidget {
  const HomeLocationButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final active = _activeLocation(ref);
    final cities = ref.watch(serviceCitiesProvider).value ?? const <ServiceCity>[];
    final feedPlace = ref.watch(homeFeedProvider.select((feed) => feed.value?.place));
    final cityName = [
      for (final city in cities)
        if (city.id == active.cityId) city.name,
    ].firstOrNull ??
        (feedPlace is CityPlace && feedPlace.city.id == active.cityId ? feedPlace.city.name : null);
    final label = active.current ? 'Current location' : cityName ?? 'Choose location';

    return Semantics(
      button: true,
      label: 'Location: $label. Change location',
      excludeSemantics: true,
      child: Material(
        color: scheme.surface,
        shape: StadiumBorder(side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.09))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            showHomeLocationPicker(context);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.primaryPink, AppTheme.burntOrange],
                    ),
                  ),
                  child: Icon(
                    active.current ? Icons.near_me_rounded : Icons.location_on_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      label,
                      key: ValueKey(label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: scheme.onSurface),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: scheme.onSurface.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the location picker sheet.
Future<void> showHomeLocationPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // Above the tab bar, which the tab's own navigator sits under.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const HomeLocationPickerSheet(),
  );
}

/// Current location, or one of the cities Myglo is in.
class HomeLocationPickerSheet extends ConsumerStatefulWidget {
  const HomeLocationPickerSheet({super.key});

  @override
  ConsumerState<HomeLocationPickerSheet> createState() => _HomeLocationPickerSheetState();
}

class _HomeLocationPickerSheetState extends ConsumerState<HomeLocationPickerSheet> {
  bool _locating = false;

  /// Why current location can't be used, once the client has tried.
  LocationAccess? _problem;

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    HapticFeedback.selectionClick();
    setState(() {
      _locating = true;
      _problem = null;
    });
    final access = await ref.read(deviceLocationProvider).requestAccess();
    if (!mounted) return;
    if (access == LocationAccess.granted) {
      // A position read before access was granted would still be null.
      ref.invalidate(passiveLocationProvider);
      await ref.read(homeLocationChoiceProvider.notifier).choose(const CurrentLocationChoice());
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _locating = false;
      _problem = access;
    });
  }

  Future<void> _chooseCity(ServiceCity city) async {
    HapticFeedback.selectionClick();
    await ref.read(homeLocationChoiceProvider.notifier).choose(CityChoice(city.id));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final active = _activeLocation(ref);
    final cities = ref.watch(serviceCitiesProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Choose your location',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.3, color: scheme.onSurface),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'We’ll show you the salons and stylists there.',
            style: TextStyle(fontSize: 14, color: scheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 20),
          _LocationOption(
            icon: Icons.near_me_rounded,
            title: 'Use my current location',
            subtitle: 'Salons closest to you',
            selected: active.current,
            busy: _locating,
            highlighted: true,
            onTap: _useCurrentLocation,
          ),
          if (_problem case final problem?) ...[
            const SizedBox(height: 10),
            _LocationProblem(access: problem),
          ],
          const SizedBox(height: 26),
          Text(
            'CITIES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 10),
          switch (cities) {
            AsyncData(:final value) when value.isEmpty => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No cities are open yet.',
                  style: TextStyle(fontSize: 14, color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
              ),
            AsyncData(:final value) => Column(
                children: [
                  for (final city in value) ...[
                    ServiceCityOption(
                      city: city,
                      selected: !active.current && active.cityId == city.id,
                      onTap: city.hasProviders ? () => _chooseCity(city) : null,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            AsyncError(:final error) => SectionErrorView(
                title: "Couldn't load cities",
                message: describeLoadError(error, subject: 'cities'),
                onRetry: () => ref.invalidate(serviceCitiesProvider),
              ),
            _ => const ServiceCityOptionsSkeleton(),
          },
        ],
      ),
    );
  }
}

/// A row in the picker: tinted icon, title, subtitle and a tick when chosen.
class _LocationOption extends StatelessWidget {
  const _LocationOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.busy = false,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool busy;

  /// Drawn with the brand gradient (the current-location row).
  final bool highlighted;

  /// Null shows the row as unavailable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: '$title, $subtitle',
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: selected ? scheme.primary.withValues(alpha: 0.06) : scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: selected ? scheme.primary.withValues(alpha: 0.5) : scheme.onSurface.withValues(alpha: 0.08),
              width: selected ? 1.4 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: busy ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: highlighted
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppTheme.primaryPink, AppTheme.burntOrange],
                            )
                          : null,
                      color: highlighted ? null : AppTheme.peach.withValues(alpha: 0.28),
                    ),
                    child: Icon(icon, size: 20, color: highlighted ? Colors.white : scheme.secondary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: scheme.onSurface),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.58)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (busy)
                    SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: scheme.primary),
                    )
                  else if (selected)
                    Icon(Icons.check_circle_rounded, color: scheme.primary)
                  else if (enabled)
                    Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withValues(alpha: 0.35)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A city in the picker or in the "no salons here" suggestions. Cities
/// without providers yet show as coming soon and can't be picked.
class ServiceCityOption extends StatelessWidget {
  const ServiceCityOption({super.key, required this.city, required this.onTap, this.selected = false});

  final ServiceCity city;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _LocationOption(
      icon: Icons.location_city_rounded,
      title: city.name,
      subtitle: city.hasProviders ? '${city.state} · ${salonCountLabel(city.providerCount)}' : '${city.state} · Coming soon',
      selected: selected,
      onTap: onTap,
    );
  }
}

/// Placeholder rows while cities load.
class ServiceCityOptionsSkeleton extends StatelessWidget {
  const ServiceCityOptionsSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SkeletonBox(height: 66, borderRadius: 18),
            ),
        ],
      ),
    );
  }
}

/// Why current location didn't work, with the one step that fixes it.
class _LocationProblem extends ConsumerWidget {
  const _LocationProblem({required this.access});

  final LocationAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final location = ref.read(deviceLocationProvider);
    final (message, actionLabel, action) = switch (access) {
      LocationAccess.deniedForever => (
          'Location access is off for Myglo. Turn it on in Settings, or pick a city below.',
          'Open Settings',
          location.openAppSettings,
        ),
      LocationAccess.serviceDisabled => (
          'Location services are off on this device. Turn them on, or pick a city below.',
          'Turn on',
          location.openLocationSettings,
        ),
      _ => ('Location access wasn’t allowed. You can pick a city below instead.', null, null),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_disabled_rounded, size: 18, color: AppTheme.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, height: 1.35, color: scheme.onSurface.withValues(alpha: 0.8)),
            ),
          ),
          if (actionLabel != null && action != null)
            TextButton(
              onPressed: action,
              style: TextButton.styleFrom(
                foregroundColor: scheme.secondary,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }
}
