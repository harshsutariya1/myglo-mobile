import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AppUserProfile Display Behavior', () {
    // Fake User for testing
    final fakeUser = User(
      id: 'id',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    );

    test('Provider displayName with provider_name', () {
      final profile = const ProfileModel(
        id: '1',
        role: UserRole.provider,
        email: 'test@test.com',
        providerName: 'Glow Spa',
        firstName: 'John',
        lastName: 'Doe',
      );
      
      final appUser = AppUserProfile(rawUser: fakeUser, role: profile.role, profile: profile);
      
      expect(appUser.displayName, 'Glow Spa');
      expect(appUser.displaySubtitle, 'John Doe');
    });

    test('Provider displayName fallback to first/last name', () {
      final profile = const ProfileModel(
        id: '1',
        role: UserRole.provider,
        email: 'test@test.com',
        firstName: 'John',
        lastName: 'Doe',
      );
      
      final appUser = AppUserProfile(rawUser: fakeUser, role: profile.role, profile: profile);
      
      expect(appUser.displayName, 'John Doe');
      expect(appUser.displaySubtitle, null);
    });

    test('Provider displayName fallback to Guest User', () {
      final profile = const ProfileModel(
        id: '1',
        role: UserRole.provider,
        email: 'test@test.com',
      );
      
      final appUser = AppUserProfile(rawUser: fakeUser, role: profile.role, profile: profile);
      
      expect(appUser.displayName, 'Guest User');
      expect(appUser.displaySubtitle, null);
    });

    test('Customer displayName with first/last name', () {
      final profile = const ProfileModel(
        id: '1',
        role: UserRole.customer,
        email: 'test@test.com',
        firstName: 'Jane',
        lastName: 'Smith',
      );
      
      final appUser = AppUserProfile(rawUser: fakeUser, role: profile.role, profile: profile);
      
      expect(appUser.displayName, 'Jane Smith');
      expect(appUser.displaySubtitle, null);
    });

    test('Customer displayName fallback to Guest User', () {
      final profile = const ProfileModel(
        id: '1',
        role: UserRole.customer,
        email: 'test@test.com',
      );
      
      final appUser = AppUserProfile(rawUser: fakeUser, role: profile.role, profile: profile);
      
      expect(appUser.displayName, 'Guest User');
      expect(appUser.displaySubtitle, null);
    });
  });
}
