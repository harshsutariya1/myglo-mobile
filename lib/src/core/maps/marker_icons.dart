import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import 'app_map.dart';

/// How a provider pin is drawn.
enum PinTone {
  standard,

  /// The pin whose card is showing: bigger, with the brand gradient ring.
  selected,

  /// Not taking bookings right now: greyed out.
  muted,
}

/// What goes into a provider pin. Equal specs give the same picture.
@immutable
class ProviderPinSpec {
  const ProviderPinSpec({
    required this.id,
    required this.initials,
    this.imageUrl,
    this.tone = PinTone.standard,
    this.approximate = false,
  });

  final String id;
  final String initials;
  final String? imageUrl;
  final PinTone tone;

  /// Mobile-only provider shown at an approximate spot: adds a car badge.
  final bool approximate;

  String get key => 'pin|$id|${imageUrl ?? ''}|$initials|${tone.name}|$approximate';
}

/// Draws map markers (provider avatar pins, cluster bubbles, a place pin) as
/// PNGs at the screen's pixel ratio, caching each picture.
///
/// Pure Flutter drawing, so no map SDK or extra package is involved and the
/// same pins work with any map provider.
class MarkerIconFactory {
  MarkerIconFactory({required this.pixelRatio});

  final double pixelRatio;

  static const int _cacheSize = 400;
  static const Duration _imageTimeout = Duration(seconds: 8);

  final LinkedHashMap<String, MarkerImage> _cache = LinkedHashMap();
  final Map<String, Future<MarkerImage>> _inFlight = {};

  /// Already-drawn picture for [key], if any (no work, no waiting).
  MarkerImage? cached(String key) {
    final image = _cache.remove(key);
    if (image != null) _cache[key] = image;
    return image;
  }

  Future<MarkerImage> providerPin(ProviderPinSpec spec) => _memo(spec.key, () => _drawProviderPin(spec));

  Future<MarkerImage> cluster(int count) => _memo('cluster|${_clusterBucket(count)}', () => _drawCluster(count));

  /// A plain branded pin for showing one place (e.g. a studio preview).
  Future<MarkerImage> placePin() => _memo('place', _drawPlacePin);

  Future<MarkerImage> _memo(String key, Future<MarkerImage> Function() draw) {
    final hit = cached(key);
    if (hit != null) return Future.value(hit);
    return _inFlight[key] ??= draw().then((image) {
      _cache[key] = image;
      while (_cache.length > _cacheSize) {
        _cache.remove(_cache.keys.first);
      }
      return image;
    }).whenComplete(() => _inFlight.remove(key));
  }

  /// Counts above 9 share a bubble per label, so "12" and "14" redraw.
  static String _clusterBucket(int count) => count > 99 ? '99+' : '$count';

  // ---------------------------------------------------------------------------
  // Drawing
  // ---------------------------------------------------------------------------

  Future<MarkerImage> _drawProviderPin(ProviderPinSpec spec) async {
    final selected = spec.tone == PinTone.selected;
    final muted = spec.tone == PinTone.muted;
    final diameter = selected ? 58.0 : 46.0;
    const pointer = 9.0;
    const pad = 6.0;
    final width = diameter + pad * 2;
    final height = diameter + pointer + pad * 2;
    final center = Offset(width / 2, pad + diameter / 2);
    final radius = diameter / 2;
    final tip = Offset(width / 2, pad + diameter + pointer);

    final avatar = spec.imageUrl == null ? null : await _loadImage(spec.imageUrl!);
    try {
      return await _render(width, height, Offset(0.5, tip.dy / height), spec.key, (canvas) {
        final body = Path()
          ..addOval(Rect.fromCircle(center: center, radius: radius))
          ..moveTo(center.dx - 8, center.dy + radius - 5)
          ..quadraticBezierTo(center.dx - 2, center.dy + radius + 2, tip.dx, tip.dy)
          ..quadraticBezierTo(center.dx + 2, center.dy + radius + 2, center.dx + 8, center.dy + radius - 5)
          ..close();
        canvas.drawShadow(body, Colors.black, selected ? 6 : 4, false);

        final ringPaint = Paint()..isAntiAlias = true;
        if (muted) {
          ringPaint.color = const Color(0xFFB9AEAE);
        } else if (selected) {
          ringPaint.shader = ui.Gradient.linear(
            Offset(0, pad),
            Offset(width, height),
            const [AppTheme.primaryPink, AppTheme.burntOrange],
          );
        } else {
          ringPaint.color = AppTheme.primaryPink;
        }
        canvas.drawPath(body, ringPaint);
        canvas.drawCircle(center, radius - 2.5, Paint()..color = Colors.white);

        final inner = Rect.fromCircle(center: center, radius: radius - 5);
        canvas.save();
        canvas.clipPath(Path()..addOval(inner));
        if (avatar != null) {
          final paint = Paint()..filterQuality = FilterQuality.high;
          if (muted) paint.colorFilter = const ColorFilter.matrix(_greyscale);
          canvas.drawImageRect(avatar, _coverSource(avatar, inner.size), inner, paint);
        } else {
          canvas.drawRect(
            inner,
            Paint()
              ..shader = ui.Gradient.linear(
                inner.topLeft,
                inner.bottomRight,
                muted
                    ? const [Color(0xFFCFC6C6), Color(0xFFA99D9D)]
                    : const [AppTheme.primaryPink, AppTheme.burntOrange],
              ),
          );
          _drawText(canvas, spec.initials, inner.center, fontSize: selected ? 19 : 15.5, color: Colors.white);
        }
        canvas.restore();

        if (spec.approximate) {
          final badgeCenter = Offset(center.dx + radius * 0.68, center.dy + radius * 0.62);
          const badgeRadius = 9.5;
          canvas.drawCircle(badgeCenter, badgeRadius + 1.5, Paint()..color = Colors.white);
          canvas.drawCircle(badgeCenter, badgeRadius, Paint()..color = AppTheme.darkRed);
          _drawIcon(canvas, Icons.directions_car_rounded, badgeCenter, size: 11.5, color: Colors.white);
        }
      });
    } finally {
      avatar?.dispose();
    }
  }

  Future<MarkerImage> _drawCluster(int count) {
    final diameter = count < 10 ? 44.0 : (count < 50 ? 52.0 : 60.0);
    const halo = 7.0;
    final size = diameter + halo * 2;
    final center = Offset(size / 2, size / 2);
    return _render(size, size, const Offset(0.5, 0.5), 'cluster|${_clusterBucket(count)}', (canvas) {
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
      _drawText(canvas, _clusterBucket(count), center, fontSize: count < 100 ? 16 : 13.5, color: Colors.white);
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
      final body = Path()
        ..addOval(Rect.fromCircle(center: center, radius: diameter / 2))
        ..moveTo(center.dx - 8, center.dy + diameter / 2 - 5)
        ..quadraticBezierTo(center.dx - 2, center.dy + diameter / 2 + 3, tip.dx, tip.dy)
        ..quadraticBezierTo(center.dx + 2, center.dy + diameter / 2 + 3, center.dx + 8, center.dy + diameter / 2 - 5)
        ..close();
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
      final png = bytes.buffer.asUint8List();
      return MarkerImage(
        key: '$key@$pixelRatio',
        png: png,
        pixelRatio: pixelRatio,
        anchor: anchor,
      );
    } finally {
      image.dispose();
    }
  }

  /// The centred part of [image] that fills [target] without distortion.
  static Rect _coverSource(ui.Image image, Size target) {
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final scale = math.max(target.width / imageSize.width, target.height / imageSize.height);
    final width = target.width / scale;
    final height = target.height / scale;
    return Rect.fromLTWH((imageSize.width - width) / 2, (imageSize.height - height) / 2, width, height);
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

  /// Decodes a provider photo through the shared image cache. Null when it
  /// can't be fetched in time; the pin then shows initials.
  Future<ui.Image?> _loadImage(String url) async {
    final completer = Completer<ui.Image?>();
    final stream = CachedNetworkImageProvider(url, maxWidth: 192, maxHeight: 192)
        .resolve(ImageConfiguration(devicePixelRatio: pixelRatio));
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!completer.isCompleted) completer.complete(info.image.clone());
        info.dispose();
      },
      onError: (error, stackTrace) {
        AppLogger.d('Marker photo failed to load: $error', tag: 'MarkerIcons');
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    stream.addListener(listener);
    try {
      return await completer.future.timeout(_imageTimeout, onTimeout: () => null);
    } finally {
      stream.removeListener(listener);
    }
  }

  static const List<double> _greyscale = [
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 0.75, 0,
  ];
}

/// Up to two initials for a name, for pins without a photo.
String markerInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'M';
  if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
  return '${parts[0].characters.first}${parts[1].characters.first}'.toUpperCase();
}
