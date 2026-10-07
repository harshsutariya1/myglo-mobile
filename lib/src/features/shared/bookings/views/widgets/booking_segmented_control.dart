import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_theme.dart';

/// One tab of a [BookingSegmentedControl].
typedef BookingSegment = ({String label, int? badge});

/// Pill-shaped tabs with an animated thumb and optional count badges.
class BookingSegmentedControl extends StatelessWidget {
  const BookingSegmentedControl({super.key, required this.segments, required this.selected, required this.onChanged});

  final List<BookingSegment> segments;
  final int selected;
  final ValueChanged<int> onChanged;

  static const double _height = 48;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      height: _height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(_height / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / segments.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: width * selected,
                top: 0,
                bottom: 0,
                width: width,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(_height / 2),
                    boxShadow: [
                      BoxShadow(color: scheme.onSurface.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 2)),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < segments.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == selected,
                        label: segments[i].badge == null || segments[i].badge == 0
                            ? segments[i].label
                            : '${segments[i].label}, ${segments[i].badge}',
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (i == selected) return;
                            HapticFeedback.selectionClick();
                            onChanged(i);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                                    fontSize: 14.5,
                                    fontWeight: i == selected ? FontWeight.w800 : FontWeight.w600,
                                    color: i == selected ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                  child: Text(segments[i].label, maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                              ),
                              if ((segments[i].badge ?? 0) > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  constraints: const BoxConstraints(minWidth: 20),
                                  height: 20,
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(10)),
                                  child: Text(
                                    '${segments[i].badge}',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: scheme.onPrimary),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
