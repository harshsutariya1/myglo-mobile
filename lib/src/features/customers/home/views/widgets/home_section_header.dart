import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

/// Title (and optional subtitle) above a home section, with an optional
/// action on the right such as "See map".
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({super.key, required this.title, this.subtitle, this.actionLabel, this.onAction});

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final label = actionLabel;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (subtitle case final subtitle?) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13.5, color: scheme.onSurface.withValues(alpha: 0.55)),
                ),
              ],
            ],
          ),
        ),
        if (label != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: scheme.secondary,
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            child: Text(label),
          ),
      ],
    );
  }
}
