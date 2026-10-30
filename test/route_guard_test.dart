import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/routing/app_router_guard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('search and the map are for clients only', () {
    for (final path in ['/search', '/map']) {
      expect(isClientOnlyPath(path), isTrue, reason: path);
      expect(isProviderOnlyPath(path), isFalse, reason: path);
    }
  });

  test('business editors are for providers only', () {
    for (final path in ['/business/profile', '/business/cover-photos', '/business/location', '/schedule/service-area']) {
      expect(isProviderOnlyPath(path), isTrue, reason: path);
      expect(isClientOnlyPath(path), isFalse, reason: path);
    }
  });

  test("the business prefix doesn't swallow the business tools tab", () {
    expect(isProviderOnlyPath('/business_tools'), isTrue);
    expect(isClientOnlyPath('/business_tools'), isFalse);
  });

  test('a provider profile seen by a client is not a provider-only page', () {
    expect(isClientOnlyPath('/provider/abc'), isTrue);
    expect(isProviderOnlyPath('/provider/abc'), isFalse);
    expect(isProviderOnlyPath('/provider_profile/settings'), isTrue);
  });

  group('admin area', () {
    User user(Map<String, dynamic> appMetadata) => User(
          id: 'u-1',
          appMetadata: appMetadata,
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
        );

    test('admin pages are admin-only and never client or provider pages', () {
      for (final path in ['/admin', '/admin/people', '/admin/people/abc', '/admin/settings/platform', '/admin-verify']) {
        expect(isAdminOnlyPath(path), isTrue, reason: path);
        expect(isClientOnlyPath(path), isFalse, reason: path);
        expect(isProviderOnlyPath(path), isFalse, reason: path);
      }
      for (final path in ['/customer_home', '/provider_home', '/administrator', '/bookings']) {
        expect(isAdminOnlyPath(path), isFalse, reason: path);
      }
    });

    test('only the server-written app_metadata flag marks an admin account', () {
      expect(isAdminAccount(user({'myglo_admin': true})), isTrue);
      expect(isAdminAccount(user({'myglo_admin': 'true'})), isFalse);
      expect(isAdminAccount(user({})), isFalse);
    });

    test('admins must pass two-factor before anything else', () {
      expect(adminRedirect('/', twoFactorPassed: false), '/admin-verify');
      expect(adminRedirect('/admin/people', twoFactorPassed: false), '/admin-verify');
      expect(adminRedirect('/customer_home', twoFactorPassed: false), '/admin-verify');
      expect(adminRedirect('/admin-verify', twoFactorPassed: false), isNull);
    });

    test('after two-factor admins stay in the admin area', () {
      expect(adminRedirect('/admin-verify', twoFactorPassed: true), '/admin');
      expect(adminRedirect('/', twoFactorPassed: true), '/admin');
      expect(adminRedirect('/provider_home', twoFactorPassed: true), '/admin');
      expect(adminRedirect('/role', twoFactorPassed: true), '/admin');
      expect(adminRedirect('/admin/settings/audit', twoFactorPassed: true), isNull);
    });
  });
}
