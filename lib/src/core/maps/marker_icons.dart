import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import 'app_map.dart';

/// How a provider pin is drawn.
enum PinTone {
  standard,

  /// The pin whose card is showing: bigger, with the brand gradient.
  selected,

  /// Not taking bookings right now: greyed out.
  muted,
}

/// What goes into a provider pin. Pins carry no per-provider content (no
/// photo, no initials), so every provider with the same look shares one
/// picture and the map uploads a handful of bitmaps instead of one each.
@immutable
class ProviderPinSpec {
  const ProviderPinSpec({this.tone = PinTone.standard, this.approximate = false});

  final PinTone tone;

  /// Mobile-only provider shown at an approximate spot: adds a car badge.
  final bool approximate;

  /// Every pin the map can show, for drawing them all up front.
  static final List<ProviderPinSpec> all = [
    for (final tone in PinTone.values)
      for (final approximate in const [false, true]) ProviderPinSpec(tone: tone, approximate: approximate),
  ];

  String get key => 'pin|${tone.name}|$approximate';

  @override
  bool operator ==(Object other) => other is ProviderPinSpec && other.tone == tone && other.approximate == approximate;

  @override
  int get hashCode => Object.hash(tone, approximate);
}

/// Draws map markers (provider pins, cluster bubbles, a place pin) as PNGs at
/// the screen's pixel ratio, caching each picture.
///
/// One factory is shared per pixel ratio for the whole app, so pictures drawn
/// for one map are ready the next time any map opens.
///
/// Pure Flutter drawing, so no map SDK or extra package is involved and the
/// same pins work with any map provider.
class MarkerIconFactory {
  factory MarkerIconFactory({required double pixelRatio}) =>
      _shared.putIfAbsent(pixelRatio, () => MarkerIconFactory._(pixelRatio));

  MarkerIconFactory._(this.pixelRatio);

  static final Map<double, MarkerIconFactory> _shared = {};

  final double pixelRatio;

  /// Fixed pins plus one bubble per cluster label (1–99 and "99+").
  static const int _cacheSize = 128;

  final LinkedHashMap<String, MarkerImage> _cache = LinkedHashMap();
  final Map<String, Future<MarkerImage>> _inFlight = {};

  /// Already-drawn picture for [key], if any (no work, no waiting).
  MarkerImage? cached(String key) {
    final image = _cache.remove(key);
    if (image != null) _cache[key] = image;
    return image;
  }

  Future<MarkerImage> providerPin(ProviderPinSpec spec) => _memo(spec.key, () => _drawProviderPin(spec));

  Future<MarkerImage> cluster(int count) => _memo(_clusterKey(count), () => _drawCluster(count));

  /// A plain branded pin for showing one place (e.g. a studio preview).
  Future<MarkerImage> placePin() => _memo('place', _drawPlacePin);

  /// Draws every provider pin ahead of time, so the first pins appear as soon
  /// as providers load instead of waiting on drawing.
  Future<void> warmUp() async {
    try {
      await Future.wait([for (final spec in ProviderPinSpec.all) providerPin(spec)]);
    } catch (e, st) {
      AppLogger.e('Pre-drawing map pins failed', tag: 'MarkerIcons', error: e, stackTrace: st);
    }
  }

  Future<MarkerImage> _memo(String key, Future<MarkerImage> Function() draw) {
    final hit = cached(key);
    if (hit != null) return Future.value(hit);
    return _inFlight[key] ??= draw().then((image) {
      _cache[key] = image;
      while (_cache.length > _cacheSize) {
        _cache.remove(_cache.keys.first);
      }
      return image;
    }).whenComplete(() {
      // Block body on purpose: returning the removed future (this very one)
      // would make whenComplete wait on itself and never finish.
      _inFlight.remove(key);
    });
  }

  static String _clusterLabel(int count) => count > 99 ? '99+' : '$count';

  static String _clusterKey(int count) => 'cluster|${_clusterLabel(count)}';

  // ---------------------------------------------------------------------------
  // Drawing
  // ---------------------------------------------------------------------------

  Future<MarkerImage> _drawProviderPin(ProviderPinSpec spec) {
    final selected = spec.tone == PinTone.selected;
    final muted = spec.tone == PinTone.muted;
    final diameter = selected ? 40.0 : 30.0;
    final pointer = selected ? 10.0 : 8.0;
    const pad = 4.0;
    final width = diameter + pad * 2;
    final height = diameter + pointer + pad * 2;
    final center = Offset(width / 2, pad + diameter / 2);
    final radius = diameter / 2;
    final tip = Offset(width / 2, pad + diameter + pointer);

    return _render(width, height, Offset(0.5, tip.dy / height), spec.key, (canvas) {
      final body = _teardrop(center, radius, tip);
      canvas.drawShadow(body, Colors.black, selected ? 5 : 3, false);
      canvas.drawPath(body, Paint()..color = Colors.white);

      final fill = Paint()..isAntiAlias = true;
      if (muted) {
        fill.color = const Color(0xFFB9AEAE);
      } else if (selected) {
        fill.shader = ui.Gradient.linear(
          center - Offset(radius, radius),
          center + Offset(radius, radius),
          const [AppTheme.primaryPink, AppTheme.burntOrange],
        );
      } else {
        fill.color = AppTheme.primaryPink;
      }
      canvas.drawPath(_teardrop(center, radius - 2, Offset(tip.dx, tip.dy - 2.5)), fill);
      canvas.drawCircle(center, radius * 0.36, Paint()..color = Colors.white);

      if (spec.approximate) {
        final badgeCenter = Offset(center.dx + radius * 0.72, center.dy - radius * 0.62);
        final badgeRadius = selected ? 8.5 : 7.0;
        canvas.drawCircle(badgeCenter, badgeRadius + 1.5, Paint()..color = Colors.white);
        canvas.drawCircle(badgeCenter, badgeRadius, Paint()..color = AppTheme.darkRed);
        _drawIcon(canvas, Icons.directions_car_rounded, badgeCenter, size: badgeRadius * 1.2, color: Colors.white);
      }
    });
  }

  Future<MarkerImage> _drawCluster(int count) {
    final diameter = count < 10 ? 44.0 : (count < 50 ? 52.0 : 60.0);
    const halo = 7.0;
    final size = diameter + halo * 2;
    final center = Offset(size / 2, size / 2);
    return _render(size, size, const Offset(0.5, 0.5), _clusterKey(count), (canvas) {
      canvas.drawCircle(center, size / 2, Paint()..color = AppTheme.primaryPink.withValues(alpha: 0.22));
      final disc = Path()..addOval(Rect.fromCircle(center: center, radius: diameter / 2));
      canvas.drawShadow(disc, Colors.black, 3, false);
      canvas.drawCircle(center, diameter / 2, Paint()..color = Colors.white);
      canvas.drawCircle(
        center,
        diameter / 2 - 2.5,
        Paint()
          ..shader = ui.Gradient.linear(
            center - Offset(diameter / 2, diameter / 2),
            center + Offset(diameter / 2, diameter / 2),
            const [AppTheme.primaryPink, AppTheme.burntOrange],
          ),
      );
      _drawText(canvas, _clusterLabel(count), center, fontSize: count < 100 ? 16 : 13.5, color: Colors.white);
    });
  }

  Future<MarkerImage> _drawPlacePin() {
    const diameter = 40.0;
    const pointer = 10.0;
    const pad = 6.0;
    const width = diameter + pad * 2;
    const height = diameter + pointer + pad * 2;
    const center = Offset(width / 2, pad + diameter / 2);
    const tip = Offset(width / 2, pad + diameter + pointer);
    return _render(width, height, const Offset(0.5, (pad + diameter + pointer) / height), 'place', (canvas) {
      final body = _teardrop(center, diameter / 2, tip);
      canvas.drawShadow(body, Colors.black, 4, false);
      canvas.drawPath(body, Paint()..color = Colors.white);
      canvas.drawCircle(
        center,
        diameter / 2 - 3,
        Paint()
          ..shader = ui.Gradient.linear(
            center - const Offset(diameter / 2, diameter / 2),
            center + const Offset(diameter / 2, diameter / 2),
            const [AppTheme.primaryPink, AppTheme.burntOrange],
          ),
      );
      _drawIcon(canvas, Icons.spa_rounded, center, size: 19, color: Colors.white);
    });
  }

  /// A round head of [radius] around [center] narrowing to a point at [tip].
  static Path _teardrop(Offset center, double radius, Offset tip) => Path()
    ..addOval(Rect.fromCircle(center: center, radius: radius))
    ..moveTo(center.dx - radius * 0.55, center.dy + radius * 0.8)
    ..quadraticBezierTo(center.dx - radius * 0.1, center.dy + radius * 1.1, tip.dx, tip.dy)
    ..quadraticBezierTo(center.dx + radius * 0.1, center.dy + radius * 1.1, center.dx + radius * 0.55, center.dy + radius * 0.8)
    ..close();

  Future<MarkerImage> _render(
    double width,
    double height,
    Offset anchor,
    String key,
    void Function(Canvas canvas) paint,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    paint(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage((width * pixelRatio).ceil(), (height * pixelRatio).ceil());
    picture.dispose();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Could not encode a map marker');
      return MarkerImage(
        key: '$key@$pixelRatio',
        png: bytes.buffer.asUint8List(),
        pixelRatio: pixelRatio,
        anchor: anchor,
      );
    } finally {
      image.dispose();
    }
  }

  static void _drawText(Canvas canvas, String text, Offset center, {required double fontSize, required Color color}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.3),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
    painter.dispose();
  }

  static void _drawIcon(Canvas canvas, IconData icon, Offset center, {required double size, required Color color}) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontSize: size, fontFamily: icon.fontFamily, package: icon.fontPackage, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
    painter.dispose();
  }
}

/// Up to two initials for a name, for avatars without a photo.
String markerInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'M';
  if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
  return '${parts[0].characters.first}${parts[1].characters.first}'.toUpperCase();
}
