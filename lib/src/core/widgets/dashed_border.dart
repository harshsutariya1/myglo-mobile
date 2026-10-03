import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// Paints a dashed rounded-rectangle outline around [child], e.g. for an
/// "add photo" drop target.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    required this.color,
    this.radius = 16,
    this.strokeWidth = 1.5,
    this.dash = 6,
    this.gap = 5,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dash: dash,
        gap: gap,
      ),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final dashed = Path();
    for (final PathMetric metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += dash + gap) {
        dashed.addPath(metric.extractPath(distance, distance + dash), Offset.zero);
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      color != old.color ||
      radius != old.radius ||
      strokeWidth != old.strokeWidth ||
      dash != old.dash ||
      gap != old.gap;
}
