import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/routing/app_router_guard.dart';

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
}
