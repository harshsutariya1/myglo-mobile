import 'package:flutter/foundation.dart';

import '../../../../core/location/geo_point.dart';

/// A service that matched a search, shown under the provider.
@immutable
class MatchedService {
  const MatchedService({
    required this.id,
    required this.name,
    this.category,
    this.price,
    this.durationMinutes,
  });

  final String id;
  final String name;
  final String? category;
  final double? price;
  final int? durationMinutes;

  factory MatchedService.fromJson(Map<String, dynamic> json) => MatchedService(
        id: json['id'] as String,
        name: (json['name'] as String?)?.trim() ?? 'Service',
        category: (json['category'] as String?)?.trim(),
        price: (json['price'] as num?)?.toDouble(),
        durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
      );
}

/// A provider as clients discover them: in search results and on the map
/// (`search_providers` / `map_providers`).
@immutable
class ProviderListing {
  const ProviderListing({
    required this.id,
    required this.name,
    this.profilePic,
    this.coverPhoto,
    this.addressText,
    this.point,
    this.approximateLocation = false,
    this.distanceKm,
    this.categories = const [],
    this.serviceCount = 0,
    this.minPrice,
    this.matchedServices = const [],
    this.acceptsBookings = true,
    this.offersStudio = true,
    this.offersMobile = false,
  });

  final String id;
  final String name;
  final String? profilePic;

  /// First cover photo, if the provider added any.
  final String? coverPhoto;

  /// Studio address. Null for mobile-only providers, whose address is private.
  final String? addressText;

  /// Where to pin them: exact for a studio, rounded to about 1 km for a
  /// mobile-only provider ([approximateLocation]). Null in search results.
  final GeoPoint? point;
  final bool approximateLocation;

  /// From the location the client shared, when they shared one.
  final double? distanceKm;
  final List<String> categories;
  final int serviceCount;

  /// Cheapest service, in AUD.
  final double? minPrice;
  final List<MatchedService> matchedServices;
  final bool acceptsBookings;
  final bool offersStudio;
  final bool offersMobile;

  /// Comes to the client and has no studio.
  bool get mobileOnly => offersMobile && !offersStudio;

  /// Best picture to represent them: their cover, else their profile photo.
  String? get imageUrl => coverPhoto ?? profilePic;

  factory ProviderListing.fromJson(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    final point = latitude == null || longitude == null ? null : GeoPoint(latitude: latitude, longitude: longitude);
    return ProviderListing(
      id: json['provider_id'] as String,
      name: _text(json['provider_name']) ?? 'Provider',
      profilePic: _text(json['profile_pic']),
      coverPhoto: _text(json['cover_photo']),
      addressText: _text(json['address_text']),
      point: point != null && point.isValid ? point : null,
      approximateLocation: json['approximate_location'] as bool? ?? false,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      categories: [
        for (final category in (json['categories'] as List?) ?? const [])
          if (_text(category) case final String value) value,
      ]..sort(),
      serviceCount: (json['service_count'] as num?)?.toInt() ?? 0,
      minPrice: (json['min_price'] as num?)?.toDouble(),
      matchedServices: [
        for (final service in (json['matched_services'] as List?) ?? const [])
          MatchedService.fromJson(Map<String, dynamic>.from(service as Map)),
      ],
      acceptsBookings: json['accepts_bookings'] as bool? ?? true,
      offersStudio: json['offers_studio'] as bool? ?? true,
      offersMobile: json['offers_mobile'] as bool? ?? false,
    );
  }

  /// The same listing with its distance measured from [origin] (used when
  /// the server didn't know where the client is).
  ProviderListing withDistanceFrom(GeoPoint? origin) {
    final from = origin;
    final to = point;
    if (from == null || to == null) return this;
    return ProviderListing(
      id: id,
      name: name,
      profilePic: profilePic,
      coverPhoto: coverPhoto,
      addressText: addressText,
      point: point,
      approximateLocation: approximateLocation,
      distanceKm: from.distanceKmTo(to),
      categories: categories,
      serviceCount: serviceCount,
      minPrice: minPrice,
      matchedServices: matchedServices,
      acceptsBookings: acceptsBookings,
      offersStudio: offersStudio,
      offersMobile: offersMobile,
    );
  }

  static String? _text(Object? value) {
    final text = value is String ? value.trim() : null;
    return text == null || text.isEmpty ? null : text;
  }
}
