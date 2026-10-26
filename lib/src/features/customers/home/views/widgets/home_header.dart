import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../shared/notifications/views/notification_bell.dart';
import '../welcome_greeting.dart';

/// "Good evening" with the brand underline, and the notification bell.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.now});

  /// Device wall clock, for the time-of-day greeting.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  timeOfDayGreeting(now),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 30,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: ExcludeSemantics(
                  child: Image.asset('assets/graphics/Underline.png', width: 84, fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.surface,
            border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(color: AppTheme.darkRed.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: const NotificationBell(size: 24),
        ),
      ],
    );
  }
}
