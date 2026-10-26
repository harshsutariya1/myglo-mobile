import 'package:flutter/foundation.dart';

import '../../../../core/location/geo_point.dart';

/// A city clients can browse providers in (`list_service_cities`). The list
/// is curated server-side.
@immutable
class ServiceCity {
  const ServiceCity({
    required this.id,
    required this.name,
    required this.state,
    required this.centre,
    required this.radiusMetres,
    this.providerCount = 0,
  });

  final String id;
  final String name;

  /// Short state code, e.g. `QLD`.
  final String state;
  final GeoPoint centre;

  /// Providers within this distance of [centre] are listed for the city.
  final double radiusMetres;

  /// How many providers are within [radiusMetres] right now.
  final int providerCount;

  bool get hasProviders => providerCount > 0;

  /// `Gold Coast, QLD`.
  String get fullName => '$name, $state';

  /// The city as Australians place something in it, for sentences like
  /// "Salons on the Gold Coast": coastal regions take "on the"
  /// (`on the Gold Coast`, `on the Sunshine Coast`), other cities "in"
  /// (`in Brisbane`).
  String get placePhrase {
    final bare = name.replaceFirst(RegExp(r'^the\s+', caseSensitive: false), '');
    return RegExp(r'\bcoast$', caseSensitive: false).hasMatch(bare) ? 'on the $bare' : 'in $bare';
  }

  /// Whether [point] falls inside this city's radius.
  bool contains(GeoPoint point) => centre.distanceKmTo(point) * 1000 <= radiusMetres;

  factory ServiceCity.fromJson(Map<String, dynamic> json) {
    final centre = GeoPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
    if (!centre.isValid) throw FormatException('Invalid centre for city ${json['city_id']}');
    final name = (json['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) throw FormatException('City ${json['city_id']} has no name');
    return ServiceCity(
      id: json['city_id'] as String,
      name: name,
      state: (json['state'] as String?)?.trim() ?? '',
      centre: centre,
      radiusMetres: (json['radius_m'] as num).toDouble(),
      providerCount: (json['provider_count'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ServiceCity &&
      other.id == id &&
      other.name == name &&
      other.state == state &&
      other.centre == centre &&
      other.radiusMetres == radiusMetres &&
      other.providerCount == providerCount;

  @override
  int get hashCode => Object.hash(id, name, state, centre, radiusMetres, providerCount);
}
