import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';

void main() {
  group('ProfileModel JSON parsing', () {
    test('Customer ProfileModel parsing', () {
      final json = {
        'id': 'user123',
        'role': 'customer',
        'first_name': 'John',
        'last_name': 'Doe',
        'email': 'john@example.com',
      };

      final profile = ProfileModel.fromJson(json);

      expect(profile.id, 'user123');
      expect(profile.role, UserRole.customer);
      expect(profile.firstName, 'John');
      expect(profile.lastName, 'Doe');
      expect(profile.email, 'john@example.com');
      expect(profile.providerName, isNull);
    });

    test('Provider ProfileModel parsing with GeoJSON', () {
      final json = {
        'id': 'prov123',
        'role': 'provider',
        'email': 'prov@example.com',
        'provider_name': 'Glow Spa',
        'address_text': '123 Spa Street',
        'coordinates': {
          'type': 'Point',
          'coordinates': [144.9631, -37.8136] // [longitude, latitude]
        }
      };

      final profile = ProfileModel.fromJson(json);

      expect(profile.id, 'prov123');
      expect(profile.role, UserRole.provider);
      expect(profile.providerName, 'Glow Spa');
      expect(profile.addressText, '123 Spa Street');
      
      expect(profile.coordinates, isNotNull);
      expect(profile.coordinates!.type, 'Point');
      expect(profile.coordinates!.coordinates.length, 2);
      expect(profile.coordinates!.coordinates[0], 144.9631); // Longitude
      expect(profile.coordinates!.coordinates[1], -37.8136); // Latitude
    });

    test('GeoJSON serialization longitude/latitude ordering', () {
      final profile = ProfileModel(
        id: 'prov123',
        role: UserRole.provider,
        email: 'prov@example.com',
        coordinates: const LocationCoordinates(
          type: 'Point',
          coordinates: [144.9631, -37.8136],
        )
      );

      final json = profile.toJson();
      final coords = json['coordinates'] as Map<String, dynamic>;
      
      expect(coords['type'], 'Point');
      expect((coords['coordinates'] as List)[0], 144.9631); // Longitude first
      expect((coords['coordinates'] as List)[1], -37.8136); // Latitude second
    });
  });
}
