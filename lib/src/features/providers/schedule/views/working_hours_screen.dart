import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../../customers/provider_profile/views/widgets/section_states.dart';
import '../../../shared/bookings/models/booking_failure.dart';
import '../../../shared/bookings/models/booking_time.dart';
import '../../../shared/bookings/models/working_hours.dart';
import '../controllers/provider_schedule_controller.dart';
import 'widgets/schedule_widgets.dart';

/// Weekly opening hours. Clients can only pick start times inside them
/// (minus bookings, time off and buffers). Saved in one transaction.
class WorkingHoursScreen extends ConsumerStatefulWidget {
  const WorkingHoursScreen({super.key});

  @override
  ConsumerState<WorkingHoursScreen> createState() => _WorkingHoursScreenState();
}

class _WorkingHoursScreenState extends ConsumerState<WorkingHoursScreen> {
  static const _defaultOpen = 9 * 60;
  static const _defaultClose = 17 * 60;

  /// What's saved, once loaded.
  WeeklySchedule? _saved;

  /// The edited week, keyed by ISO weekday.
  final Map<int, List<WorkingHoursRange>> _draft = {};
  bool _saving = false;

  WeeklySchedule get _draftSchedule => WeeklySchedule([for (final day in _draft.values) ...day]);

  bool get _dirty {
    final saved = _saved;
    if (saved == null) return false;
    final draft = _draftSchedule.ranges;
    if (draft.length != saved.ranges.length) return true;
    for (var i = 0; i < draft.length; i++) {
      if (draft[i] != saved.ranges[i]) return true;
    }
    return false;
  }

  void _load(WeeklySchedule schedule) {
    _saved = schedule;
    _draft
      ..clear()
      ..addAll({for (var day = 1; day <= 7; day++) day: schedule.on(day)});
  }

  void _setDay(int weekday, List<WorkingHoursRange> ranges) => setState(() => _draft[weekday] = ranges);

  void _toggleDay(int weekday, bool open) {
    HapticFeedback.selectionClick();
    _setDay(
      weekday,
      open ? [WorkingHoursRange(weekday: weekday, opensMinutes: _defaultOpen, closesMinutes: _defaultClose)] : const [],
    );
  }

  void _applyPreset(Iterable<int> weekdays) {
    HapticFeedback.selectionClick();
    setState(() {
      for (var day = 1; day <= 7; day++) {
        _draft[day] = weekdays.contains(day)
            ? [WorkingHoursRange(weekday: day, opensMinutes: _defaultOpen, closesMinutes: _defaultClose)]
            : const [];
      }
    });
  }

  void _copyDay(int from, Iterable<int> to) {
    HapticFeedback.selectionClick();
    final source = _draft[from] ?? const [];
    setState(() {
      for (final day in to) {
        if (day == from) continue;
        _draft[day] = [
          for (final range in source)
            WorkingHoursRange(weekday: day, opensMinutes: range.opensMinutes, closesMinutes: range.closesMinutes),
        ];
      }
    });
    context.showAppSnackBar('Copied ${Formatters.weekdayLong(_dayDate(from))} hours');
  }

  Future<void> _editTime(int weekday, int index, {required bool opening}) async {
    final ranges = [...?_draft[weekday]];
    final range = ranges[index];
    final picked = await showTimeWheelSheet(
      context,
      title: opening ? 'Opens at' : 'Closes at',
      initialMinutes: opening ? range.opensMinutes : range.closesMinutes,
      allowMidnightEnd: !opening,
    );
    if (picked == null || !mounted) return;
    ranges[index] = opening ? range.copyWith(opensMinutes: picked) : range.copyWith(closesMinutes: picked);
    _setDay(weekday, ranges);
  }

  void _addRange(int weekday) {
    final ranges = [...?_draft[weekday]];
    final lastClose = ranges.isEmpty ? _defaultOpen : ranges.last.closesMinutes;
    // Suggest an hour's break then two hours of work, within the day.
    final opens = (lastClose + 60).clamp(0, 1440 - 60);
    final closes = (opens + 120).clamp(opens + 15, 1440);
    ranges.add(WorkingHoursRange(weekday: weekday, opensMinutes: opens, closesMinutes: closes));
    _setDay(weekday, ranges);
  }

  void _removeRange(int weekday, int index) {
    final ranges = [...?_draft[weekday]]..removeAt(index);
    _setDay(weekday, ranges);
  }

  Future<void> _save() async {
    final schedule = _draftSchedule;
    if (schedule.validationError != null) return;
    setState(() => _saving = true);
    try {
      final saved = await ref.read(providerScheduleActionsProvider).saveWorkingHours(schedule);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _load(saved));
      context.showAppSnackBar('Working hours saved');
    } on BookingFailure catch (failure) {
      if (mounted) context.showAppSnackBar(failure.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static DateTime _dayDate(int weekday) => DateTime.utc(2024, 1, weekday);

  /// Problem with one day's ranges, if any.
  static String? _dayError(List<WorkingHoursRange> ranges) {
    for (var i = 0; i < ranges.length; i++) {
      if (!ranges[i].isValid) return 'Closing time must be after opening time.';
      for (var j = i + 1; j < ranges.length; j++) {
        if (ranges[i].overlaps(ranges[j])) return 'These times overlap.';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final async = ref.watch(ownWorkingHoursProvider);
    if (_saved == null && async.value != null) _load(async.value!);
    final error = _saved == null ? null : _draftSchedule.validationError;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmDiscardChanges(context) && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
          title: const Text('Working hours'),
        ),
        bottomNavigationBar: _saved == null
            ? null
            : SaveBar(
                label: 'Save working hours',
                busy: _saving,
                message: error,
                onPressed: _dirty && error == null ? _save : null,
              ),
        body: switch (_saved) {
          null when async.hasError => Center(
              child: SingleChildScrollView(
                child: SectionErrorView(
                  title: "Hours didn't load",
                  message: describeLoadError(async.error!, subject: 'your working hours'),
                  onRetry: () => ref.invalidate(ownWorkingHoursProvider),
                ),
              ),
            ),
          null => const _HoursSkeleton(),
          _ => ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Text(
                  'Clients can book start times inside these hours. Times are in '
                  '${BookingTime.label(BookingTime.defaultTimeZone)}.',
                  style: TextStyle(fontSize: 14, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.65)),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PresetChip(label: 'Mon–Fri, 9–5', onTap: () => _applyPreset(const [1, 2, 3, 4, 5])),
                    _PresetChip(label: 'Mon–Sat, 9–5', onTap: () => _applyPreset(const [1, 2, 3, 4, 5, 6])),
                    _PresetChip(label: 'Every day, 9–5', onTap: () => _applyPreset(const [1, 2, 3, 4, 5, 6, 7])),
                  ],
                ),
                const SizedBox(height: 18),
                for (var day = 1; day <= 7; day++) ...[
                  _DayCard(
                    label: Formatters.weekdayLong(_dayDate(day)),
                    ranges: _draft[day] ?? const [],
                    error: _dayError(_draft[day] ?? const []),
                    enabled: !_saving,
                    onToggle: (open) => _toggleDay(day, open),
                    onEditTime: (index, opening) => _editTime(day, index, opening: opening),
                    onAddRange: (_draft[day]?.length ?? 0) < WeeklySchedule.maxRangesPerDay ? () => _addRange(day) : null,
                    onRemoveRange: (index) => _removeRange(day, index),
                    onCopyToAll: () => _copyDay(day, const [1, 2, 3, 4, 5, 6, 7]),
                    onCopyToWeekdays: () => _copyDay(day, const [1, 2, 3, 4, 5]),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 17, color: scheme.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Changing your hours doesn't affect bookings already made. To block out a holiday or a "
                        'single day, add time off instead.',
                        style: TextStyle(fontSize: 13, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        },
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(Icons.bolt_rounded, size: 16, color: scheme.secondary),
      label: Text(label),
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurface),
      backgroundColor: scheme.primary.withValues(alpha: 0.08),
      side: BorderSide.none,
      shape: const StadiumBorder(),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.label,
    required this.ranges,
    required this.error,
    required this.enabled,
    required this.onToggle,
    required this.onEditTime,
    required this.onAddRange,
    required this.onRemoveRange,
    required this.onCopyToAll,
    required this.onCopyToWeekdays,
  });

  final String label;
  final List<WorkingHoursRange> ranges;
  final String? error;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final void Function(int index, bool opening) onEditTime;
  final VoidCallback? onAddRange;
  final ValueChanged<int> onRemoveRange;
  final VoidCallback onCopyToAll;
  final VoidCallback onCopyToWeekdays;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final open = ranges.isNotEmpty;
    final muted = scheme.onSurface.withValues(alpha: 0.55);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      decoration: BoxDecoration(
        color: open ? scheme.surface : scheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: error != null ? AppTheme.destructive.withValues(alpha: 0.5) : scheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: scheme.onSurface),
                ),
              ),
              if (!open) Text('Closed', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: muted)),
              if (open)
                PopupMenuButton<VoidCallback>(
                  tooltip: 'Copy $label hours',
                  enabled: enabled,
                  icon: Icon(Icons.copy_all_rounded, size: 20, color: muted),
                  onSelected: (action) => action(),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: onCopyToWeekdays, child: const Text('Copy to Mon–Fri')),
                    PopupMenuItem(value: onCopyToAll, child: const Text('Copy to every day')),
                  ],
                ),
              Switch.adaptive(value: open, onChanged: enabled ? onToggle : null),
            ],
          ),
          if (open) ...[
            for (var i = 0; i < ranges.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _TimeButton(
                        label: WorkingHoursRange.formatMinutes(ranges[i].opensMinutes),
                        semanticLabel: 'Opens at ${WorkingHoursRange.formatMinutes(ranges[i].opensMinutes)}',
                        onTap: enabled ? () => onEditTime(i, true) : null,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('–', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: muted)),
                    ),
                    Expanded(
                      child: _TimeButton(
                        label: WorkingHoursRange.formatMinutes(ranges[i].closesMinutes),
                        semanticLabel: 'Closes at ${WorkingHoursRange.formatMinutes(ranges[i].closesMinutes)}',
                        onTap: enabled ? () => onEditTime(i, false) : null,
                      ),
                    ),
                    if (ranges.length > 1)
                      IconButton(
                        tooltip: 'Remove these hours',
                        onPressed: enabled ? () => onRemoveRange(i) : null,
                        icon: Icon(Icons.remove_circle_outline_rounded, size: 21, color: muted),
                      )
                    else
                      const SizedBox(width: 8),
                  ],
                ),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  error!,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.destructive),
                ),
              ),
            if (onAddRange != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: enabled ? onAddRange : null,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add hours'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.secondary,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.label, required this.semanticLabel, required this.onTap});

  final String label;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: scheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 44,
            child: Center(
              child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface)),
            ),
          ),
        ),
      ),
    );
  }
}

class _HoursSkeleton extends StatelessWidget {
  const _HoursSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const SkeletonText(style: TextStyle(fontSize: 14, height: 1.45), widthFactor: 0.9),
          const SizedBox(height: 18),
          for (var i = 0; i < 7; i++) ...[
            const SkeletonBox(height: 104, borderRadius: 18),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
