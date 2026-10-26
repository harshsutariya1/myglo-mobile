import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/location/device_location.dart';
import '../../../../core/location/geo_point.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../explore/models/explore_repository.dart';
import '../../explore/models/provider_listing.dart';
import '../models/service_city.dart';
import 'home_location_controller.dart';

/// Where the home feed is looking.
@immutable
sealed class HomePlace {
  const HomePlace();
}

/// Around the device's (coarsened) position.
final class NearDevicePlace extends HomePlace {
  const NearDevicePlace();

  @override
  bool operator ==(Object other) => other is NearDevicePlace;

  @override
  int get hashCode => (NearDevicePlace).hashCode;
}

/// Within one of the curated cities.
final class CityPlace extends HomePlace {
  const CityPlace(this.city);

  final ServiceCity city;

  @override
  bool operator ==(Object other) => other is CityPlace && other.city == city;

  @override
  int get hashCode => city.hashCode;
}

/// Providers for the client home screen.
@immutable
class HomeFeed {
  const HomeFeed({required this.providers, required this.place, this.locationUnavailable = false});

  /// Nearest first from where [place] looks.
  final List<ProviderListing> providers;

  /// Null only when there are no cities to fall back to.
  final HomePlace? place;

  /// The client chose their current location but the device didn't give one
  /// (permission withdrawn, location services off), so [place] is a city.
  final bool locationUnavailable;

  /// Distances only mean something when measured from the client.
  bool get showDistance => place is NearDevicePlace;
}

/// The city a client sees when we can't use their location and they haven't
/// picked one: the first (in the curated order) that has providers.
ServiceCity? defaultServiceCity(List<ServiceCity> cities) {
  for (final city in cities) {
    if (city.hasProviders) return city;
  }
  return cities.isEmpty ? null : cities.first;
}

/// The providers for the client's chosen city, or around them when they
/// chose (or, by default, allowed) their current location. Never prompts for
/// location: a position is used only if access was already granted.
final homeFeedProvider = FutureProvider.autoDispose<HomeFeed>((ref) async {
  // The saved choice is per account: wait for it, so a cold start doesn't
  // load (and flash) the default place first.
  await ref.watch(userProfileProvider.selectAsync((profile) => profile?.rawUser.id));
  final choice = ref.watch(homeLocationChoiceProvider);
  final repository = ref.watch(exploreRepositoryProvider);

  Future<HomeFeed> inCity(ServiceCity city, {bool locationUnavailable = false}) async => HomeFeed(
        providers: await repository.providersAround(
          city.centre,
          radiusMetres: city.radiusMetres,
          limit: AppConfig.homeProvidersLimit,
        ),
        place: CityPlace(city),
        locationUnavailable: locationUnavailable,
      );

  if (choice case CityChoice(:final cityId)) {
    final cities = await ref.watch(serviceCitiesProvider.future);
    for (final city in cities) {
      if (city.id == cityId) return inCity(city);
    }
    // The city was removed or switched off: fall back like a first visit.
  }

  GeoPoint? position;
  try {
    // A first fix can take a few seconds; wait longer when the client asked
    // for their location than when it's only the default.
    final wait = choice is CurrentLocationChoice ? const Duration(seconds: 8) : const Duration(seconds: 3);
    position = await ref.watch(passiveLocationProvider.future).timeout(wait);
  } catch (_) {
    // No position in time: use a city instead.
  }

  if (position != null) {
    return HomeFeed(
      providers: await repository.providersAround(
        position.coarse(),
        radiusMetres: AppConfig.homeProvidersRadiusMetres,
        limit: AppConfig.homeProvidersLimit,
      ),
      place: const NearDevicePlace(),
    );
  }

  final city = defaultServiceCity(await ref.watch(serviceCitiesProvider.future));
  if (city == null) return const HomeFeed(providers: [], place: null);
  return inCity(city, locationUnavailable: choice is CurrentLocationChoice);
});
