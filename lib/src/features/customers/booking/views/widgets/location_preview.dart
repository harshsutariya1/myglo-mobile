import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

/// A picture of where an appointment is.
///
/// Maps aren't integrated yet, so this paints a stylised street map with a
/// pin, varied by the address so each place looks a little different. When
/// Google Maps lands, swap the painter for a static map image behind this
/// same widget; no screen needs to change.
class LocationPreview extends StatelessWidget {
  const LocationPreview({super.key, required this.label, this.height = 150});

  /// Usually the address; also seeds the drawing.
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Semantics(
      label: 'Map preview of $label',
      image: true,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
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
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 12, color: scheme.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text(
                        'Map coming soon',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
