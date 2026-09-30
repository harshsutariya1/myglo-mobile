import 'package:flutter/material.dart';

/// Colours used by skeleton placeholders, derived from the active
/// [ColorScheme] so they follow light and dark themes.
///
/// The base tone tints the container surface with a little `onSurface`; the
/// highlight is a lighter tint of the page surface. Both stay legible whether
/// or not the palette defines explicit `surfaceContainer*` roles.
class SkeletonColors {
  const SkeletonColors({required this.base, required this.highlight});

  final Color base;
  final Color highlight;

  factory SkeletonColors.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SkeletonColors(
      base: Color.alphaBlend(
        scheme.onSurface.withValues(alpha: 0.08),
        scheme.surfaceContainerHighest,
      ),
      highlight: Color.alphaBlend(
        scheme.onSurface.withValues(alpha: 0.02),
        scheme.surface,
      ),
    );
  }
}

/// Paints a moving highlight across every [SkeletonBox] below it.
///
/// Wrap a whole skeleton layout in a single [Shimmer] so all placeholders
/// animate in sync. The sweep is disabled when the platform asks for reduced
/// motion.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  static const Duration period = Duration(milliseconds: 1400);

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Shimmer.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
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
    final colors = SkeletonColors.of(context);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) => LinearGradient(
              colors: [colors.base, colors.highlight, colors.base],
              stops: const [0.35, 0.5, 0.65],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              transform: _SlideGradient(_controller.value),
            ).createShader(bounds),
            child: child,
          );
        },
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.progress);

  final double progress;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    // Sweep from fully off the left edge to fully off the right edge.
    final dx = bounds.width * (progress * 2 - 1);
    return Matrix4.translationValues(dx, 0, 0);
  }
}

/// A solid placeholder block. Only visible when placed under a [Shimmer].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
  }) : _circle = false;

  const SkeletonBox.circle({super.key, required double size})
    : width = size,
      height = size,
      borderRadius = 0,
      _circle = true;

  final double? width;
  final double? height;
  final double borderRadius;
  final bool _circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: SkeletonColors.of(context).base,
        shape: _circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: _circle ? null : BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A placeholder for one line of text.
///
/// It takes exactly the height a real [Text] with [style] would take (so the
/// layout does not shift when content arrives) and paints a slimmer bar
/// centred inside that line box.
class SkeletonText extends StatelessWidget {
  const SkeletonText({
    super.key,
    required this.style,
    this.width,
    this.widthFactor,
  }) : assert(width == null || widthFactor == null);

  final TextStyle style;

  /// Fixed bar width.
  final double? width;

  /// Bar width as a fraction of the available width. Defaults to full width
  /// when neither this nor [width] is given.
  final double? widthFactor;

  @override
  Widget build(BuildContext context) {
    final line = Text(
      ' ',
      maxLines: 1,
      style: style.copyWith(color: Colors.transparent),
    );
    final fontSize = style.fontSize ?? DefaultTextStyle.of(context).style.fontSize ?? 14;
    final bar = Stack(
      children: [
        SizedBox(width: double.infinity, child: line),
        Positioned.fill(
          child: Center(
            child: SkeletonBox(
              height: fontSize * 0.8,
              borderRadius: fontSize * 0.3,
            ),
          ),
        ),
      ],
    );

    if (width != null) return SizedBox(width: width, child: bar);
    return FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: widthFactor ?? 1,
      child: bar,
    );
  }
}
