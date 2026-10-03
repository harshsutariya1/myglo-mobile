import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/utils/image_crop.dart';
import 'package:myglo/src/features/providers/provider_profiles/models/service_catalog.dart';
import 'package:myglo/src/features/providers/provider_profiles/models/service_repository.dart';

void main() {
  group('ServiceDescription.parse', () {
    test('splits bullet lines into the included list', () {
      final parsed = ServiceDescription.parse(
        'A deep-cleansing treatment.\n\n• Pre-wash\n- Treatment application\n* Blow-dry\nFinished with a gloss.',
      );
      expect(parsed.summary, 'A deep-cleansing treatment.\nFinished with a gloss.');
      expect(parsed.included, ['Pre-wash', 'Treatment application', 'Blow-dry']);
    });

    test('handles plain text and empty descriptions', () {
      expect(ServiceDescription.parse('Just a trim').included, isEmpty);
      expect(ServiceDescription.parse('Just a trim').summary, 'Just a trim');
      final empty = ServiceDescription.parse('');
      expect(empty.summary, isEmpty);
      expect(empty.included, isEmpty);
    });

    test('ignores bare bullets and hyphenated words', () {
      final parsed = ServiceDescription.parse('•\nWell-being focused\n-not a bullet');
      expect(parsed.included, isEmpty);
      expect(parsed.summary, '•\nWell-being focused\n-not a bullet');
    });
  });

  group('serviceImagePathFromUrl', () {
    const base = 'https://x.supabase.co/storage/v1/object/public/service-images';

    test('extracts the object path and drops the cache-buster', () {
      expect(serviceImagePathFromUrl('$base/user-1/abc.jpg?t=123'), 'user-1/abc.jpg');
      expect(serviceImagePathFromUrl('$base/user-1/abc.jpg'), 'user-1/abc.jpg');
    });

    test('returns null for other buckets or missing values', () {
      expect(serviceImagePathFromUrl(null), isNull);
      expect(serviceImagePathFromUrl('https://x.supabase.co/storage/v1/object/public/post-media/a.jpg'), isNull);
      expect(serviceImagePathFromUrl('$base/'), isNull);
    });
  });

  group('centerCropRect', () {
    test('crops the sides of a wide image', () {
      expect(centerCropRect(const Size(400, 200), 1), const Rect.fromLTWH(100, 0, 200, 200));
    });

    test('crops the top and bottom of a tall image', () {
      expect(centerCropRect(const Size(400, 1000), 4 / 5), const Rect.fromLTWH(0, 250, 400, 500));
    });

    test('keeps an image that already matches', () {
      expect(centerCropRect(const Size(1600, 900), 16 / 9), const Rect.fromLTWH(0, 0, 1600, 900));
    });
  });
}
