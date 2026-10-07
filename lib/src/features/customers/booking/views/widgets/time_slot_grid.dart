import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../shared/bookings/models/available_slot.dart';

/// A day's free start times, grouped into morning, afternoon and evening.
class TimeSlotGrid extends StatelessWidget {
  const TimeSlotGrid({
    super.key,
    required this.slots,
    required this.selected,
    required this.durationMinutes,
    required this.onSelected,
  });

  final List<AvailableSlot> slots;
  final AvailableSlot? selected;

  /// Length of the appointment, for the spoken end time.
  final int durationMinutes;
  final ValueChanged<AvailableSlot> onSelected;

  static const double spacing = 10;

  /// Chips per row for the available width.
  static int columnsFor(double width) => width < 330 ? 3 : 4;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final groups = SlotCalendar.byPeriod(slots);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(constraints.maxWidth);
        final chipWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 10),
                child: Row(
                  children: [
                    Icon(_iconFor(entry.key), size: 17, color: scheme.secondary),
                    const SizedBox(width: 6),
                    Semantics(
                      header: true,
                      child: Text(
                        entry.key.label,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: scheme.onSurface),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${entry.value.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final slot in entry.value)
                    SizedBox(
                      width: chipWidth,
                      child: _SlotChip(
                        key: ValueKey(slot.startsAt),
                        slot: slot,
                        selected: slot == selected,
                        durationMinutes: durationMinutes,
                        onTap: () => onSelected(slot),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }

  static IconData _iconFor(SlotPeriod period) => switch (period) {
        SlotPeriod.morning => Icons.wb_twilight_rounded,
        SlotPeriod.afternoon => Icons.wb_sunny_outlined,
        SlotPeriod.evening => Icons.nights_stay_outlined,
      };
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    super.key,
    required this.slot,
    required this.selected,
    required this.durationMinutes,
    required this.onTap,
  });

  final AvailableSlot slot;
  final bool selected;
  final int durationMinutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final radius = BorderRadius.circular(14);
    return Semantics(
      button: true,
      selected: selected,
      label: '${Formatters.time(slot.local)} to ${Formatters.time(slot.localEnd(durationMinutes))}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 46,
        decoration: BoxDecoration(
          color: selected ? scheme.onSurface : scheme.surface,
          borderRadius: radius,
          border: Border.all(color: selected ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.12)),
          boxShadow: selected
              ? [BoxShadow(color: scheme.onSurface.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4))]
              : const [],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  Formatters.time(slot.local),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? scheme.surface : scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder chips while a day's times load. Place under a [Shimmer].
class TimeSlotGridSkeleton extends StatelessWidget {
  const TimeSlotGridSkeleton({super.key, this.count = 8});

  final int count;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = TimeSlotGrid.columnsFor(constraints.maxWidth);
        final width = (constraints.maxWidth - TimeSlotGrid.spacing * (columns - 1)) / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6, bottom: 10),
              child: SkeletonBox(width: 96, height: 16, borderRadius: 8),
            ),
            Wrap(
              spacing: TimeSlotGrid.spacing,
              runSpacing: TimeSlotGrid.spacing,
              children: [
                for (var i = 0; i < count; i++) SkeletonBox(width: width, height: 46, borderRadius: 14),
              ],
            ),
          ],
        );
      },
    );
  }
}
