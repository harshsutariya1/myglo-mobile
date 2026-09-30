import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/utils/formatters.dart';
import 'package:myglo/src/core/utils/geo.dart';
import 'package:myglo/src/features/customers/home/views/welcome_greeting.dart';

void main() {
  group('firstNameFrom', () {
    test('returns the first whitespace-separated token', () {
      expect(firstNameFrom('Priya'), 'Priya');
      expect(firstNameFrom('Mary Jane'), 'Mary');
      expect(firstNameFrom('  Ana \t Lucia  '), 'Ana');
    });

    test('returns null for missing or blank names', () {
      expect(firstNameFrom(null), isNull);
      expect(firstNameFrom(''), isNull);
      expect(firstNameFrom('   \n\t '), isNull);
    });
  });

  group('Formatters.aud', () {
    test('drops cents on whole dollars', () {
      expect(Formatters.aud(45), r'$45');
      expect(Formatters.aud(45.0), r'$45');
      expect(Formatters.aud(0), r'$0');
    });

    test('shows two decimals otherwise', () {
      expect(Formatters.aud(45.5), r'$45.50');
      expect(Formatters.aud(19.99), r'$19.99');
      expect(Formatters.aud(0.05), r'$0.05');
    });

    test('groups thousands with commas', () {
      expect(Formatters.aud(1250), r'$1,250');
      expect(Formatters.aud(1234567.8), r'$1,234,567.80');
      expect(Formatters.aud(999), r'$999');
    });

    test('rounds to the nearest cent and handles negatives', () {
      expect(Formatters.aud(10.006), r'$10.01');
      expect(Formatters.aud(-12.5), r'-$12.50');
    });
  });

  group('Formatters.duration', () {
    test('formats minutes and hours', () {
      expect(Formatters.duration(45), '45 min');
      expect(Formatters.duration(60), '1 hr');
      expect(Formatters.duration(90), '1 hr 30 min');
      expect(Formatters.duration(125), '2 hr 5 min');
      expect(Formatters.duration(0), '0 min');
    });
  });

  group('Formatters.relativeTime', () {
    final now = DateTime.utc(2026, 9, 30, 12);

    test('uses short relative labels within a week', () {
      expect(Formatters.relativeTime(now.subtract(const Duration(seconds: 30)), now: now), 'Just now');
      expect(Formatters.relativeTime(now.subtract(const Duration(minutes: 5)), now: now), '5m ago');
      expect(Formatters.relativeTime(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
      expect(Formatters.relativeTime(now.subtract(const Duration(days: 2)), now: now), '2d ago');
    });

    test('falls back to a calendar date after a week', () {
      final lastMonth = DateTime.utc(2026, 8, 15, 12);
      final expected = '${lastMonth.toLocal().day} Aug';
      expect(Formatters.relativeTime(lastMonth, now: now), expected);
    });

    test('includes the year for dates in another year', () {
      final lastYear = DateTime.utc(2025, 6, 15, 12);
      expect(Formatters.relativeTime(lastYear, now: now), endsWith('2025'));
    });

    test('compares instants regardless of time zone', () {
      final fiveMinutesAgoLocal = now.toLocal().subtract(const Duration(minutes: 5));
      expect(Formatters.relativeTime(fiveMinutesAgoLocal, now: now), '5m ago');
    });
  });

  group('Formatters.distanceKm', () {
    test('switches units and precision by range', () {
      expect(Formatters.distanceKm(0.85), '850 m');
      expect(Formatters.distanceKm(0.0001), '1 m');
      expect(Formatters.distanceKm(4.23), '4.2 km');
      expect(Formatters.distanceKm(18.4), '18 km');
    });
  });

  group('Geo.distanceKm', () {
    // GeoJSON order: [longitude, latitude].
    const surfersParadise = [153.4310, -28.0023];
    const broadbeach = [153.4312, -28.0337];

    test('returns the great-circle distance between two points', () {
      final km = Geo.distanceKm(surfersParadise, broadbeach)!;
      expect(km, closeTo(3.49, 0.05));
    });

    test('is zero for identical points', () {
      expect(Geo.distanceKm(surfersParadise, surfersParadise), 0);
    });

    test('returns null when a point is missing or malformed', () {
      expect(Geo.distanceKm(null, broadbeach), isNull);
      expect(Geo.distanceKm(surfersParadise, const [153.4]), isNull);
      expect(Geo.distanceKm(surfersParadise, const [200, 10]), isNull);
      expect(Geo.distanceKm(surfersParadise, const [10, -95]), isNull);
    });
  });
}
