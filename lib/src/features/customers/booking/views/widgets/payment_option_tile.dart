import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/soon_badge.dart';
import 'selectable_service_tile.dart' show SelectionCheck;

/// One way to pay. Methods that aren't live yet are drawn faded with a
/// "Coming soon" pill and can't be selected.
class PaymentOptionTile extends StatelessWidget {
  const PaymentOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.available = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool available;

  /// Selects the method, or explains it isn't available yet.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final radius = BorderRadius.circular(18);
    final fade = available ? 1.0 : 0.45;

    return Semantics(
      button: available,
      selected: selected,
      enabled: available,
      label: '$title. $subtitle${available ? '' : '. Coming soon'}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
            onTap: () {
              if (available) HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  Opacity(
                    opacity: fade,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: available ? scheme.primary.withValues(alpha: 0.12) : scheme.onSurface.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, size: 22, color: available ? scheme.secondary : scheme.onSurface),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Opacity(
                      opacity: fade,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(fontSize: 13, height: 1.35, color: scheme.onSurface.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (available) SelectionCheck(selected: selected, size: 24) else const SoonBadge(label: 'Coming soon'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
