import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../shared/notifications/views/notification_bell.dart';
import '../welcome_greeting.dart';
import 'home_location_picker.dart';

/// The home app bar: "Good evening" with the brand underline, then the
/// location selector and the notification bell.
///
/// The greeting shrinks to fit narrow screens (down to [minGreetingFontSize])
/// so the buttons always keep their room.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.now});

  static const double maxGreetingFontSize = 30;
  static const double minGreetingFontSize = 22;

  /// Width of the brand underline at [maxGreetingFontSize]; it scales with
  /// the greeting.
  static const double _underlineWidth = 84;

  /// Device wall clock, for the time-of-day greeting.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final greeting = timeOfDayGreeting(now);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final style = TextStyle(
                fontSize: maxGreetingFontSize,
                height: 1.15,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                color: scheme.onSurface,
              );
              final fontSize = fittingFontSize(
                greeting,
                style: style,
                maxWidth: constraints.maxWidth,
                textScaler: MediaQuery.textScalerOf(context),
                min: minGreetingFontSize,
                max: maxGreetingFontSize,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      greeting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style.copyWith(fontSize: fontSize),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: ExcludeSemantics(
                      child: Image.asset(
                        'assets/graphics/Underline.png',
                        width: _underlineWidth * fontSize / maxGreetingFontSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        const _HeaderAction(child: HomeLocationButton()),
        const SizedBox(width: 8),
        const _HeaderAction(child: NotificationBell(size: 24)),
      ],
    );
  }
}

/// The largest font size from [max] down to [min] (in whole points) at which
/// [text] fits on one line in [maxWidth]. [min] when nothing fits; the text
/// then ellipsises.
@visibleForTesting
double fittingFontSize(
  String text, {
  required TextStyle style,
  required double maxWidth,
  required TextScaler textScaler,
  required double min,
  required double max,
}) {
  if (!maxWidth.isFinite) return max;
  for (var size = max; size > min; size -= 1) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style.copyWith(fontSize: size)),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final fits = painter.width <= maxWidth;
    painter.dispose();
    if (fits) return size;
  }
  return min;
}

/// The round, softly shadowed frame around each app bar button.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surface,
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: AppTheme.darkRed.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}
