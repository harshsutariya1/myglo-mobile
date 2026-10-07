import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_theme.dart';
import 'selectable_service_tile.dart' show SelectionCheck;

/// A selectable way to have the appointment (at the studio / at home).
///
/// Shows [child] underneath while selected. A disabled card explains itself
/// with [disabledReason].
class LocationOptionCard extends StatelessWidget {
  const LocationOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onSelected,
    this.disabledReason,
    this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onSelected;

  /// Non-null disables the card and is shown as its subtitle.
  final String? disabledReason;
  final Widget? child;

  static const Duration _animation = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final enabled = disabledReason == null;
    final radius = BorderRadius.circular(22);

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '$title. ${disabledReason ?? subtitle}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: _animation,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withValues(alpha: 0.05) : scheme.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.09),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled && !selected
                ? () {
                    HapticFeedback.selectionClick();
                    onSelected();
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: enabled ? scheme.primary.withValues(alpha: 0.12) : scheme.onSurface.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 22,
                          color: enabled ? scheme.secondary : scheme.onSurface.withValues(alpha: 0.35),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface.withValues(alpha: enabled ? 1 : 0.45),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              disabledReason ?? subtitle,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.35,
                                color: scheme.onSurface.withValues(alpha: enabled ? 0.6 : 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (enabled) SelectionCheck(selected: selected, size: 24),
                    ],
                  ),
                  AnimatedSize(
                    duration: _animation,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: selected && child != null
                        ? Padding(padding: const EdgeInsets.only(top: 16), child: child)
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
