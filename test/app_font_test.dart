import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/theme/app_theme.dart';

/// The theme's font family must be bundled (pubspec `fonts:`), otherwise
/// Flutter silently falls back to SF Pro / Roboto.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expectedWeights = [300, 400, 500, 600, 700, 800, 900];

  late List<dynamic> familyFonts;

  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    final family = manifest.cast<Map<String, dynamic>>().firstWhere(
      (entry) => entry['family'] == AppTheme.fontFamily,
      orElse: () => fail('${AppTheme.fontFamily} is not declared in pubspec'),
    );
    familyFonts = family['fonts'] as List<dynamic>;

    final loader = FontLoader(AppTheme.fontFamily);
    for (final font in familyFonts.cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  });

  test('declares every upright weight the app uses (300–900)', () {
    final upright = familyFonts
        .cast<Map<String, dynamic>>()
        .where((font) => font['style'] != 'italic')
        .map((font) => font['weight'])
        .toList();
    expect(upright, containsAll(expectedWeights));
  });

  test('theme uses the bundled family', () {
    final theme = AppTheme.lightTheme;
    expect(theme.textTheme.bodyMedium?.fontFamily, AppTheme.fontFamily);
    expect(theme.appBarTheme.titleTextStyle?.fontFamily, AppTheme.fontFamily);
  });

  test('heavier weights render wider glyphs', () {
    double widthAt(int weight) {
      final painter = TextPainter(
        text: TextSpan(
          text: 'Book your glow',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 40,
            fontWeight: FontWeight.values[weight ~/ 100 - 1],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final widths = expectedWeights.map(widthAt).toList();
    for (var i = 1; i < widths.length; i++) {
      expect(
        widths[i],
        greaterThan(widths[i - 1]),
        reason:
            'w${expectedWeights[i]} should be wider than '
            'w${expectedWeights[i - 1]}',
      );
    }
  });
}
