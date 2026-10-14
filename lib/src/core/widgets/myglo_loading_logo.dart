import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Animated Myglo logo used as a buffering indicator ("Whisper Trace").
///
/// The 16 petals light up one after another around the logo — each lifts
/// slightly outward, brightens, then settles back — while the centre star
/// breathes. Ported from the "Whisper Trace" mode of
/// `assets/myglo_buffering_animation_studio.html`; the geometry is drawn in a
/// 1000×1000 design space and scaled to [size].
///
/// When the platform asks for reduced motion the full logo is shown static.
class MygloLoadingLogo extends StatefulWidget {
  const MygloLoadingLogo({super.key, this.size = 120});

  final double size;

  @override
  State<MygloLoadingLogo> createState() => _MygloLoadingLogoState();
}

class _MygloLoadingLogoState extends State<MygloLoadingLogo>
    with SingleTickerProviderStateMixin {
  // Petals loop every 1.8 s and the star every 2.0 s; 18 s is the shortest
  // span both divide evenly, so the repeat never visibly jumps.
  static const _loop = Duration(seconds: 18);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _loop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _WhisperTracePainter(
            controller: _controller,
            loopSeconds: _loop.inMilliseconds / 1000,
            animate: !reduceMotion,
          ),
        ),
      ),
    );
  }
}

/// Visual state of one petal at a moment in the Whisper Trace loop.
@immutable
class WhisperPetalFrame {
  const WhisperPetalFrame({
    required this.lift,
    required this.scale,
    required this.opacity,
    required this.saturation,
    required this.brightness,
  });

  /// Outward offset in design units (1000-unit logo space).
  final double lift;
  final double scale;
  final double opacity;
  final double saturation;
  final double brightness;

  static const rest = WhisperPetalFrame(
    lift: 0,
    scale: 0.96,
    opacity: 0.16,
    saturation: 0.4,
    brightness: 1,
  );

  static const peak = WhisperPetalFrame(
    lift: 8,
    scale: 1.02,
    opacity: 1,
    saturation: 1.15,
    brightness: 1.05,
  );

  /// Undimmed logo, used when animations are disabled.
  static const still = WhisperPetalFrame(
    lift: 0,
    scale: 1,
    opacity: 1,
    saturation: 1,
    brightness: 1,
  );

  static WhisperPetalFrame lerp(
    WhisperPetalFrame a,
    WhisperPetalFrame b,
    double t,
  ) {
    double l(double x, double y) => x + (y - x) * t;
    return WhisperPetalFrame(
      lift: l(a.lift, b.lift),
      scale: l(a.scale, b.scale),
      opacity: l(a.opacity, b.opacity),
      saturation: l(a.saturation, b.saturation),
      brightness: l(a.brightness, b.brightness),
    );
  }
}

/// Visual state of the centre star at a moment in its breathing loop.
@immutable
class WhisperStarFrame {
  const WhisperStarFrame({required this.scale, required this.opacity});

  final double scale;
  final double opacity;

  static const rest = WhisperStarFrame(scale: 0.98, opacity: 0.85);
  static const peak = WhisperStarFrame(scale: 1.03, opacity: 1);
  static const still = WhisperStarFrame(scale: 1, opacity: 1);
}

/// Keyframe timing for the Whisper Trace animation, kept separate from the
/// painting so it can be unit-tested.
abstract final class WhisperTrace {
  static const petalPeriod = 1.8;
  static const petalStagger = 0.1125;
  static const starPeriod = 2.0;

  /// Same curve as the source's `cubic-bezier(0.4, 0, 0.2, 1)`.
  static const _petalCurve = Curves.fastOutSlowIn;

  /// Same curve as the source's CSS `ease-in-out`.
  static const _starCurve = Curves.easeInOut;

  /// Petal [sequence] (0–15, clockwise from the top ray) at [seconds].
  ///
  /// Rises to [WhisperPetalFrame.peak] over the first 20% of its loop, falls
  /// back by 50%, then rests until the next pass.
  static WhisperPetalFrame petalAt(double seconds, int sequence) {
    final phase = _phase(seconds - sequence * petalStagger, petalPeriod);
    if (phase < 0.2) {
      return WhisperPetalFrame.lerp(
        WhisperPetalFrame.rest,
        WhisperPetalFrame.peak,
        _petalCurve.transform(phase / 0.2),
      );
    }
    if (phase < 0.5) {
      return WhisperPetalFrame.lerp(
        WhisperPetalFrame.peak,
        WhisperPetalFrame.rest,
        _petalCurve.transform((phase - 0.2) / 0.3),
      );
    }
    return WhisperPetalFrame.rest;
  }

  static WhisperStarFrame starAt(double seconds) {
    final phase = _phase(seconds, starPeriod);
    final t = phase < 0.5
        ? _starCurve.transform(phase / 0.5)
        : 1 - _starCurve.transform((phase - 0.5) / 0.5);
    const a = WhisperStarFrame.rest;
    const b = WhisperStarFrame.peak;
    return WhisperStarFrame(
      scale: a.scale + (b.scale - a.scale) * t,
      opacity: a.opacity + (b.opacity - a.opacity) * t,
    );
  }

  static double _phase(double seconds, double period) {
    final p = (seconds / period) % 1.0;
    return p < 0 ? p + 1 : p;
  }
}

class _WhisperTracePainter extends CustomPainter {
  _WhisperTracePainter({
    required this.controller,
    required this.loopSeconds,
    required this.animate,
  }) : super(repaint: controller);

  final AnimationController controller;
  final double loopSeconds;
  final bool animate;

  static const _design = 1000.0;
  static const _centre = Offset(500, 500);

  // Petal colours, clockwise from 22.5°: 2 pink (top), 2 lime (right),
  // 2 purple (bottom), 2 blue (left).
  static final _dropGradients = [
    _pinkDrop,
    _limeDrop,
    _limeDrop,
    _purpleDrop,
    _purpleDrop,
    _blueDrop,
    _blueDrop,
    _pinkDrop,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final seconds = controller.value * loopSeconds;
    canvas.save();
    canvas.scale(size.width / _design, size.height / _design);

    // Long peach rays sit on the even sequence slots (0°, 45°, …) and the
    // coloured drops on the odd ones (22.5°, 67.5°, …), so the trace runs
    // ray, drop, ray, drop around the logo.
    final rays = [
      for (var i = 0; i < 8; i++)
        (angle: i * 45.0, frame: _petalFrame(seconds, i * 2)),
    ];
    final drops = [
      for (var i = 0; i < 8; i++)
        (angle: 22.5 + i * 45.0, frame: _petalFrame(seconds, i * 2 + 1)),
    ];

    // Shadows go under each whole group, as with the source's group filter.
    for (final ray in rays) {
      _paintShadow(canvas, _longRayBody, ray.angle, ray.frame);
    }
    for (final ray in rays) {
      _paintPetal(canvas, ray.angle, ray.frame, _paintLongRay);
    }

    for (final drop in drops) {
      _paintShadow(canvas, _dropBody, drop.angle, drop.frame);
    }
    for (var i = 0; i < drops.length; i++) {
      final gradient = _dropGradients[i];
      _paintPetal(
        canvas,
        drops[i].angle,
        drops[i].frame,
        (c) => _paintDrop(c, gradient),
      );
    }

    _paintStar(
      canvas,
      animate ? WhisperTrace.starAt(seconds) : WhisperStarFrame.still,
    );
    canvas.restore();
  }

  WhisperPetalFrame _petalFrame(double seconds, int sequence) => animate
      ? WhisperTrace.petalAt(seconds, sequence)
      : WhisperPetalFrame.still;

  /// Rotates to [angle] around the centre, lifts outward and scales.
  void _applyPetalTransform(
    Canvas canvas,
    double angle,
    WhisperPetalFrame frame,
  ) {
    canvas.translate(_centre.dx, _centre.dy);
    canvas.rotate(angle * math.pi / 180);
    canvas.translate(0, -frame.lift);
    canvas.scale(frame.scale);
    canvas.translate(-_centre.dx, -_centre.dy);
  }

  void _paintShadow(
    Canvas canvas,
    Path body,
    double angle,
    WhisperPetalFrame frame,
  ) {
    for (final shadow in _shadows) {
      canvas.save();
      // The shadow falls straight down on screen, whatever the petal angle.
      canvas.translate(0, shadow.dy);
      _applyPetalTransform(canvas, angle, frame);
      canvas.drawPath(
        body,
        Paint()
          ..color = shadow.color.withValues(
            alpha: shadow.color.a * frame.opacity,
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.sigma),
      );
      canvas.restore();
    }
  }

  void _paintPetal(
    Canvas canvas,
    double angle,
    WhisperPetalFrame frame,
    void Function(Canvas) paintBody,
  ) {
    canvas.save();
    _applyPetalTransform(canvas, angle, frame);
    canvas.saveLayer(
      const Rect.fromLTWH(0, 0, _design, _design),
      Paint()
        ..colorFilter = ColorFilter.matrix(
          _filterMatrix(frame.saturation, frame.brightness, frame.opacity),
        ),
    );
    paintBody(canvas);
    canvas.restore();
    canvas.restore();
  }

  void _paintLongRay(Canvas canvas) {
    canvas.drawPath(_longRayBody, _fill(_longRayBody, _peachRay));
    canvas.drawPath(
      _longRayBevel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFFFFD9C9).withValues(alpha: 0.55),
    );
    canvas.drawPath(_longRayGloss, _fill(_longRayGloss, _glossSpecular));
    canvas.save();
    canvas.translate(482, 82);
    canvas.rotate(-18 * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 9, height: 18),
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
    canvas.restore();
  }

  void _paintDrop(Canvas canvas, _BoxGradient gradient) {
    canvas.drawPath(_dropBody, _fill(_dropBody, gradient));
    canvas.drawPath(_dropGloss, _fill(_dropGloss, _glossSpecular));
  }

  void _paintStar(Canvas canvas, WhisperStarFrame frame) {
    canvas.save();
    canvas.translate(_centre.dx, _centre.dy);
    canvas.scale(frame.scale);
    canvas.translate(-_centre.dx, -_centre.dy);
    canvas.saveLayer(
      const Rect.fromLTWH(0, 0, _design, _design),
      Paint()..color = Colors.black.withValues(alpha: frame.opacity),
    );
    for (final shadow in _shadows) {
      canvas.drawPath(
        _starBody.shift(Offset(0, shadow.dy)),
        Paint()
          ..color = shadow.color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.sigma),
      );
    }
    canvas.drawPath(_starBody, _fill(_starBody, _peachStar));
    canvas.drawPath(_starGloss, _fill(_starGloss, _glossSpecular));
    canvas.drawPath(
      _starRim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFCAB5).withValues(alpha: 0.45),
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WhisperTracePainter oldDelegate) =>
      oldDelegate.animate != animate ||
      oldDelegate.controller != controller ||
      oldDelegate.loopSeconds != loopSeconds;
}

/// Saturate → brightness → opacity, matching CSS `saturate()` and
/// `brightness()` filter maths.
List<double> _filterMatrix(double s, double b, double opacity) {
  return [
    (0.213 + 0.787 * s) * b,
    (0.715 - 0.715 * s) * b,
    (0.072 - 0.072 * s) * b,
    0,
    0,
    (0.213 - 0.213 * s) * b,
    (0.715 + 0.285 * s) * b,
    (0.072 - 0.072 * s) * b,
    0,
    0,
    (0.213 - 0.213 * s) * b,
    (0.715 - 0.715 * s) * b,
    (0.072 + 0.928 * s) * b,
    0,
    0,
    0,
    0,
    0,
    opacity,
    0,
  ];
}

Paint _fill(Path path, _BoxGradient gradient) =>
    Paint()..shader = gradient.shaderFor(path.getBounds());

/// A linear gradient in SVG `objectBoundingBox` units: [begin]/[end] are
/// fractions of the shape's bounds, and the gradient is stretched with the
/// box (unlike Flutter's [LinearGradient], which keeps it unskewed).
class _BoxGradient {
  const _BoxGradient(this.begin, this.end, this.colors, this.stops);

  final Offset begin;
  final Offset end;
  final List<Color> colors;
  final List<double> stops;

  Shader shaderFor(Rect box) {
    // Column-major: scale to the box size, then move to its top-left.
    final matrix = Float64List.fromList([
      box.width, 0, 0, 0, //
      0, box.height, 0, 0, //
      0, 0, 1, 0, //
      box.left, box.top, 0, 1,
    ]);
    return ui.Gradient.linear(
      begin,
      end,
      colors,
      stops,
      TileMode.clamp,
      matrix,
    );
  }
}

typedef _Shadow = ({double dy, double sigma, Color color});

/// The source's "ceramic" drop shadow: a soft wide one plus a tight contact one.
const List<_Shadow> _shadows = [
  (dy: 14, sigma: 12, color: Color(0x382D1E18)),
  (dy: 3, sigma: 4, color: Color(0x1F1F1612)),
];

const _peachStar = _BoxGradient(
  Offset(0.20, 0.15),
  Offset(0.85, 0.85),
  [Color(0xFFFFD1BD), Color(0xFFF7AA8C), Color(0xFFEB8E6B), Color(0xFFD97957)],
  [0, 0.45, 0.85, 1],
);

const _peachRay = _BoxGradient(
  Offset(0.15, 0.05),
  Offset(0.85, 0.95),
  [Color(0xFFFFD4C2), Color(0xFFF7AA8C), Color(0xFFEC916E), Color(0xFFDC7B58)],
  [0, 0.35, 0.80, 1],
);

const _pinkDrop = _BoxGradient(
  Offset(0.15, 0.10),
  Offset(0.85, 0.95),
  [Color(0xFFFFAAE0), Color(0xFFF36CB8), Color(0xFFDC4A9B), Color(0xFFB8327B)],
  [0, 0.40, 0.85, 1],
);

const _limeDrop = _BoxGradient(
  Offset(0.15, 0.10),
  Offset(0.85, 0.95),
  [Color(0xFFF4FFAD), Color(0xFFD9EB67), Color(0xFFBDD147), Color(0xFF9CB02E)],
  [0, 0.40, 0.85, 1],
);

const _purpleDrop = _BoxGradient(
  Offset(0.15, 0.10),
  Offset(0.85, 0.95),
  [Color(0xFFF3B8FF), Color(0xFFCF76E6), Color(0xFFB253CC), Color(0xFF8E37A8)],
  [0, 0.40, 0.85, 1],
);

const _blueDrop = _BoxGradient(
  Offset(0.15, 0.10),
  Offset(0.85, 0.95),
  [Color(0xFFBCEEFF), Color(0xFF76C5E8), Color(0xFF53A8CF), Color(0xFF3887AD)],
  [0, 0.40, 0.85, 1],
);

const _glossSpecular = _BoxGradient(
  Offset(0, 0),
  Offset(0, 1),
  [Color(0xEBFFFFFF), Color(0x73FFFFFF), Color(0x00FFFFFF)],
  [0, 0.55, 1],
);

// Geometry below is in the 1000×1000 design space, each petal drawn pointing
// straight up from the centre (500, 500) before rotation.

final Path _longRayBody = Path()
  ..moveTo(500, 52)
  ..cubicTo(526, 52, 542, 72, 539, 102)
  ..lineTo(516, 342)
  ..cubicTo(514, 358, 508, 365, 500, 365)
  ..cubicTo(492, 365, 486, 358, 484, 342)
  ..lineTo(461, 102)
  ..cubicTo(458, 72, 474, 52, 500, 52)
  ..close();

final Path _longRayBevel = Path()
  ..moveTo(500, 58)
  ..cubicTo(520, 58, 533, 74, 531, 100)
  ..lineTo(511, 336)
  ..cubicTo(509, 348, 505, 353, 500, 353)
  ..cubicTo(495, 353, 491, 348, 489, 336)
  ..lineTo(469, 100)
  ..cubicTo(467, 74, 480, 58, 500, 58)
  ..close();

final Path _longRayGloss = Path()
  ..moveTo(503, 64)
  ..cubicTo(519, 65, 529, 78, 527, 102)
  ..lineTo(510, 330)
  ..cubicTo(509, 338, 505, 338, 505, 330)
  ..lineTo(518, 102)
  ..cubicTo(519, 84, 512, 73, 501, 70)
  ..close();

final Path _dropBody = Path()
  ..moveTo(500, 136)
  ..cubicTo(522, 136, 535, 154, 530, 180)
  ..lineTo(508, 302)
  ..cubicTo(505, 314, 502, 318, 500, 318)
  ..cubicTo(498, 318, 495, 314, 492, 302)
  ..lineTo(470, 180)
  ..cubicTo(465, 154, 478, 136, 500, 136)
  ..close();

final Path _dropGloss = Path()
  ..moveTo(503, 144)
  ..cubicTo(517, 145, 525, 157, 521, 178)
  ..lineTo(504, 286)
  ..cubicTo(503, 292, 500, 291, 501, 284)
  ..lineTo(512, 178)
  ..cubicTo(514, 162, 509, 153, 501, 150)
  ..close();

final Path _starBody = Path()
  ..moveTo(500, 396)
  ..cubicTo(511, 396, 525, 442, 544, 458)
  ..cubicTo(562, 475, 604, 489, 604, 500)
  ..cubicTo(604, 511, 562, 525, 544, 542)
  ..cubicTo(525, 558, 511, 604, 500, 604)
  ..cubicTo(489, 604, 475, 558, 456, 542)
  ..cubicTo(438, 525, 396, 511, 396, 500)
  ..cubicTo(396, 489, 438, 475, 456, 458)
  ..cubicTo(475, 442, 489, 396, 500, 396)
  ..close();

final Path _starGloss = Path()
  ..moveTo(503, 410)
  ..cubicTo(511, 414, 524, 447, 540, 462)
  ..cubicTo(555, 477, 586, 489, 590, 496)
  ..cubicTo(582, 494, 551, 483, 534, 468)
  ..cubicTo(518, 453, 506, 424, 503, 410)
  ..close();

final Path _starRim = Path()
  ..moveTo(412, 504)
  ..cubicTo(436, 514, 452, 526, 465, 540)
  ..cubicTo(478, 554, 490, 575, 496, 590);
