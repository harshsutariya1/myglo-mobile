import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/location/geo_point.dart';
import '../../../../../core/maps/app_map.dart';
import '../../../../../core/maps/marker_icons.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/app_logger.dart';

/// A small, non-interactive map of where an appointment is.
///
/// With a [point] it shows the real map (through the app's map interface,
/// so no screen depends on a map SDK) with a branded pin. Without one it
/// paints a stylised street map, varied by the address so each place looks
/// a little different.
class LocationPreview extends StatefulWidget {
  const LocationPreview({super.key, required this.label, this.point, this.height = 150});

  /// Usually the address; also seeds the drawing when there's no [point].
  final String label;
  final GeoPoint? point;
  final double height;

  @override
  State<LocationPreview> createState() => _LocationPreviewState();
}

class _LocationPreviewState extends State<LocationPreview> {
  MarkerImage? _pin;
  double? _pinRatio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ratio = MediaQuery.devicePixelRatioOf(context);
    if (widget.point != null && _pinRatio != ratio) {
      _pinRatio = ratio;
      MarkerIconFactory(pixelRatio: ratio).placePin().then((pin) {
        if (mounted) setState(() => _pin = pin);
      }).catchError((Object e, StackTrace st) {
        AppLogger.e('Drawing the map preview pin failed', tag: 'LocationPreview', error: e, stackTrace: st);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = widget.point;
    final pin = _pin;
    return Semantics(
      label: 'Map of ${widget.label}',
      image: true,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: point == null || !point.isValid
              ? _PaintedMap(label: widget.label)
              : AppMap(
                  key: ValueKey(point),
                  initialCamera: MapCamera(target: point, zoom: 15.5),
                  markers: [if (pin != null) AppMapMarker(id: 'place', point: point, image: pin)],
                  interactive: false,
                  lite: true,
                ),
        ),
      ),
    );
  }
}

/// The stand-in drawing used when there are no coordinates to map.
class _PaintedMap extends StatelessWidget {
  const _PaintedMap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _StreetMapPainter(seed: label.hashCode)),
        Center(
          child: Transform.translate(
            offset: const Offset(0, -10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(color: scheme.primary.withValues(alpha: 0.45), blurRadius: 16, spreadRadius: 2),
                    ],
                  ),
                  child: const Icon(Icons.spa_rounded, size: 16, color: Colors.white),
                ),
                Container(
                  width: 10,
                  height: 4,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StreetMapPainter extends CustomPainter {
  const _StreetMapPainter({required this.seed});

  final int seed;

  static const _land = Color(0xFFF4EEE9);
  static const _block = Color(0xFFEDE4DD);
  static const _park = Color(0xFFDCEBD7);
  static const _water = Color(0xFFD5E5F1);
  static const _street = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    canvas.drawRect(Offset.zero & size, Paint()..color = _land);

    // Water along one edge.
    final waterOnLeft = random.nextBool();
    final water = Path();
    final edge = waterOnLeft ? 0.0 : size.width;
    final reach = size.width * (0.12 + random.nextDouble() * 0.08);
    final inward = waterOnLeft ? reach : -reach;
    water.moveTo(edge, 0);
    water.cubicTo(edge + inward * 1.3, size.height * 0.3, edge + inward * 0.6, size.height * 0.7, edge + inward, size.height);
    water.lineTo(edge, size.height);
    water.close();
    canvas.drawPath(water, Paint()..color = _water);

    // City blocks between streets.
    const street = 9.0;
    final columns = 5 + random.nextInt(2);
    const rows = 4;
    final blockWidth = size.width / columns;
    final blockHeight = size.height / rows;
    final blockPaint = Paint()..color = _block;
    final parkPaint = Paint()..color = _park;
    final parkColumn = 1 + random.nextInt(columns - 2);
    final parkRow = random.nextInt(rows);
    for (var c = 0; c < columns; c++) {
      for (var r = 0; r < rows; r++) {
        final rect = Rect.fromLTWH(
          c * blockWidth + street / 2,
          r * blockHeight + street / 2,
          blockWidth - street,
          blockHeight - street,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(5)),
          c == parkColumn && r == parkRow ? parkPaint : blockPaint,
        );
      }
    }

    // A main road crossing diagonally.
    final road = Paint()
      ..color = _street
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final start = Offset(0, size.height * (0.2 + random.nextDouble() * 0.6));
    final end = Offset(size.width, size.height * (0.2 + random.nextDouble() * 0.6));
    canvas.drawLine(start, end, road);
    canvas.drawLine(start, end, Paint()
      ..color = const Color(0xFFF7D9C9)
      ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_StreetMapPainter oldDelegate) => oldDelegate.seed != seed;
}
