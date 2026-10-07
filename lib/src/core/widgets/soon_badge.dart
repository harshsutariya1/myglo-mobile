import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Small neutral "Soon" tag for controls that aren't live yet.
class SoonBadge extends StatelessWidget {
  const SoonBadge({super.key, this.label = 'Soon'});

  /// E.g. `Coming soon` where there's room for it.
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: scheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
