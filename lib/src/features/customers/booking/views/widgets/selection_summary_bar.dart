import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../models/service_selection.dart';

/// Sticky footer of the booking screen: the running total (tap to review the
/// selection) and the Continue action.
///
/// Slides in with the first selected service and out again when the
/// selection is cleared.
class SelectionSummaryBar extends StatelessWidget {
  const SelectionSummaryBar({
    super.key,
    required this.selection,
    required this.onReview,
    required this.onContinue,
  });

  static const Duration _animation = Duration(milliseconds: 260);

  final ServiceSelection selection;
  final VoidCallback onReview;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: _animation,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: selection.isEmpty
          ? const SizedBox(key: ValueKey('empty'), width: double.infinity)
          : _Bar(
              key: const ValueKey('bar'),
              selection: selection,
              onReview: onReview,
              onContinue: onContinue,
            ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({super.key, required this.selection, required this.onReview, required this.onContinue});

  final ServiceSelection selection;
  final VoidCallback onReview;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final total = Formatters.aud(selection.total);
    final meta = '${selection.countLabel} · ${Formatters.duration(selection.totalMinutes)}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: scheme.onSurface.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Total $total for $meta. Review selected services',
                excludeSemantics: true,
                child: InkWell(
                  onTap: onReview,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: muted),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                transitionBuilder: (child, animation) => FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween(begin: const Offset(0, 0.25), end: Offset.zero)
                                        .animate(animation),
                                    child: child,
                                  ),
                                ),
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [...previous, ?current],
                                ),
                                child: Text(
                                  total,
                                  key: ValueKey(selection.totalCents),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 21,
                                    height: 1.15,
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.keyboard_arrow_up_rounded, size: 22, color: scheme.onSurface),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.onSurface,
                  foregroundColor: scheme.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Continue'),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
