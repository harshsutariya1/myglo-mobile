import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/widgets/myglo_loading_logo.dart';
import 'package:myglo/src/features/shared/authentication/views/screens/splash_screen.dart';

void main() {
  group('WhisperTrace timing', () {
    test('petal starts its loop at rest and peaks at 20%', () {
      final start = WhisperTrace.petalAt(0, 0);
      expect(start.opacity, closeTo(WhisperPetalFrame.rest.opacity, 1e-9));
      expect(start.lift, closeTo(0, 1e-9));

      final peak = WhisperTrace.petalAt(0.2 * WhisperTrace.petalPeriod, 0);
      expect(peak.opacity, closeTo(1, 1e-9));
      expect(peak.lift, closeTo(8, 1e-9));
      expect(peak.scale, closeTo(1.02, 1e-9));
      expect(peak.saturation, closeTo(1.15, 1e-9));
      expect(peak.brightness, closeTo(1.05, 1e-9));
    });

    test('petal is back at rest for the second half of its loop', () {
      for (final fraction in [0.5, 0.7, 0.99]) {
        final frame = WhisperTrace.petalAt(
          fraction * WhisperTrace.petalPeriod,
          0,
        );
        expect(frame.opacity, closeTo(WhisperPetalFrame.rest.opacity, 1e-9));
        expect(frame.lift, closeTo(0, 1e-9));
      }
    });

    test('each petal trails the previous one by the stagger', () {
      const t = 0.2 * WhisperTrace.petalPeriod;
      for (var seq = 0; seq < 16; seq++) {
        final frame = WhisperTrace.petalAt(
          t + seq * WhisperTrace.petalStagger,
          seq,
        );
        expect(frame.opacity, closeTo(1, 1e-4), reason: 'petal $seq');
      }
    });

    test('loop repeats seamlessly', () {
      for (var seq = 0; seq < 16; seq++) {
        final a = WhisperTrace.petalAt(0.37, seq);
        final b = WhisperTrace.petalAt(0.37 + WhisperTrace.petalPeriod, seq);
        expect(b.opacity, closeTo(a.opacity, 1e-9));
        expect(b.lift, closeTo(a.lift, 1e-9));
      }
    });

    test('star breathes between rest and peak every 2 seconds', () {
      expect(WhisperTrace.starAt(0).scale, closeTo(0.98, 1e-9));
      expect(WhisperTrace.starAt(0).opacity, closeTo(0.85, 1e-9));
      expect(WhisperTrace.starAt(1).scale, closeTo(1.03, 1e-9));
      expect(WhisperTrace.starAt(1).opacity, closeTo(1, 1e-9));
      expect(WhisperTrace.starAt(2).scale, closeTo(0.98, 1e-9));
    });
  });

  group('MygloLoadingLogo', () {
    testWidgets('animates and disposes cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: MygloLoadingLogo())),
      );
      expect(
        tester.getSize(find.byType(MygloLoadingLogo)),
        const Size(120, 120),
      );
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('stays still when animations are disabled', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(child: MygloLoadingLogo()),
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  testWidgets('splash shows the logo above the progress line', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 1300));

    final logo = find.byType(MygloLoadingLogo);
    final line = find.byType(LinearProgressIndicator);
    expect(logo, findsOneWidget);
    expect(line, findsOneWidget);
    expect(
      tester.getRect(logo).bottom,
      lessThanOrEqualTo(tester.getRect(line).top),
    );
    expect(tester.getCenter(logo).dx, closeTo(tester.getCenter(line).dx, 0.5));
  });
}
