import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../../customers/provider_profile/views/widgets/section_states.dart';
import '../../../shared/bookings/models/booking.dart';
import '../../../shared/bookings/models/booking_failure.dart';
import '../../../shared/bookings/models/booking_repository.dart';
import '../../../shared/bookings/models/booking_time.dart';
import '../../../shared/bookings/models/working_hours.dart';
import '../../../shared/bookings/views/widgets/booking_list_view.dart';
import '../controllers/provider_schedule_controller.dart';
import '../models/time_off.dart';
import 'widgets/schedule_widgets.dart';

/// Holidays, days off and one-off blocks. Clients can't book inside them;
/// bookings already made stay as they are.
class TimeOffScreen extends ConsumerWidget {
  const TimeOffScreen({super.key});

  String _timeZone(WidgetRef ref) =>
      ref.watch(ownBookingSettingsProvider.select((s) => s.value?.timeZone)) ?? BookingTime.defaultTimeZone;

  Future<void> _delete(BuildContext context, WidgetRef ref, TimeOffBlock block, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove time off?'),
        content: Text('$label will be open for bookings again (within your working hours).'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.destructive, foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(providerScheduleActionsProvider).deleteTimeOff(block.id);
      if (context.mounted) context.showAppSnackBar('Time off removed');
    } on BookingFailure catch (failure) {
      if (context.mounted) context.showAppSnackBar(failure.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final timeZone = _timeZone(ref);
    final async = ref.watch(ownTimeOffProvider);
    final blocks = async.value;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Time off'),
      ),
      bottomNavigationBar: SaveBar(
        label: 'Add time off',
        onPressed: () => showAddTimeOffSheet(context, timeZone: timeZone),
      ),
      body: RefreshIndicator(
        color: scheme.primary,
        onRefresh: () async {
          ref.invalidate(ownTimeOffProvider);
          try {
            await ref.read(ownTimeOffProvider.future);
          } catch (_) {
            // Shown inline.
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text(
              "Block out holidays, appointments and days off. Clients can't book these times. "
              'Times are in ${BookingTime.label(timeZone)}.',
              style: TextStyle(fontSize: 14, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.65)),
            ),
            const SizedBox(height: 18),
            if (blocks == null && async.hasError)
              SectionErrorView(
                title: "Time off didn't load",
                message: describeLoadError(async.error!, subject: 'your time off'),
                onRetry: () => ref.invalidate(ownTimeOffProvider),
              )
            else if (blocks == null)
              const Shimmer(
                child: Column(
                  children: [
                    SkeletonBox(height: 76, borderRadius: 18),
                    SizedBox(height: 12),
                    SkeletonBox(height: 76, borderRadius: 18),
                  ],
                ),
              )
            else if (blocks.isEmpty)
              const BookingsEmptyState(
                icon: Icons.beach_access_outlined,
                title: 'No time off planned',
                message: 'Add a holiday or a day off and those times disappear from your booking page.',
              )
            else
              for (final block in blocks) ...[
                _TimeOffCard(
                  block: block,
                  timeZone: timeZone,
                  onDelete: (label) => _delete(context, ref, block, label),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

/// `Mon 6 Oct – Wed 8 Oct` + `All day`, or `Mon 6 Oct` + `9:00 am – 1:00 pm`.
({String title, String subtitle}) describeTimeOff(TimeOffBlock block, String timeZone) {
  final start = BookingTime.wallClockOf(block.startsAt, timeZone);
  final end = BookingTime.wallClockOf(block.endsAt, timeZone);
  final allDay = start.hour == 0 && start.minute == 0 && end.hour == 0 && end.minute == 0;
  if (allDay) {
    final lastDay = BookingTime.dateOf(end).subtract(const Duration(days: 1));
    final sameDay = BookingTime.dateOf(start) == lastDay;
    return (
      title: sameDay ? Formatters.dateShort(start) : '${Formatters.dateShort(start)} – ${Formatters.dateShort(lastDay)}',
      subtitle: sameDay ? 'All day' : 'All day · ${lastDay.difference(BookingTime.dateOf(start)).inDays + 1} days',
    );
  }
  if (BookingTime.dateOf(start) == BookingTime.dateOf(end)) {
    return (title: Formatters.dateShort(start), subtitle: Formatters.timeRange(start, end));
  }
  return (title: '${Formatters.dateTimeShort(start)} –', subtitle: Formatters.dateTimeShort(end));
}

class _TimeOffCard extends StatelessWidget {
  const _TimeOffCard({required this.block, required this.timeZone, required this.onDelete});

  final TimeOffBlock block;
  final String timeZone;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final text = describeTimeOff(block, timeZone);
    final ongoing = block.covers(DateTime.now().toUtc());
    final reason = block.reason;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (ongoing ? AppTheme.warning : scheme.primary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.event_busy_outlined, size: 21, color: ongoing ? AppTheme.warning : scheme.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        text.title,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scheme.onSurface),
                      ),
                    ),
                    if (ongoing) ...[
                      const SizedBox(width: 8),
                      const Text(
                        'NOW',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppTheme.warning,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [text.subtitle, if (reason != null && reason.isNotEmpty) reason].join(' · '),
                  style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove time off',
            onPressed: () => onDelete(text.title),
            icon: Icon(Icons.delete_outline_rounded, color: scheme.onSurface.withValues(alpha: 0.55)),
          ),
        ],
      ),
    );
  }
}

/// Sheet for adding time off in the provider's [timeZone].
Future<void> showAddTimeOffSheet(BuildContext context, {required String timeZone}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _AddTimeOffSheet(timeZone: timeZone),
  );
}

class _AddTimeOffSheet extends ConsumerStatefulWidget {
  const _AddTimeOffSheet({required this.timeZone});

  final String timeZone;

  @override
  ConsumerState<_AddTimeOffSheet> createState() => _AddTimeOffSheetState();
}

class _AddTimeOffSheetState extends ConsumerState<_AddTimeOffSheet> {
  static const _maxReasonLength = 120;
  static const _maxDays = 366;

  final _reason = TextEditingController();
  late DateTime _fromDate = BookingTime.todayIn(widget.timeZone);
  late DateTime _toDate = _fromDate;
  int _fromMinutes = 9 * 60;
  int _toMinutes = 17 * 60;
  bool _allDay = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  DateTime get _startLocal => _allDay ? _fromDate : _fromDate.add(Duration(minutes: _fromMinutes));

  DateTime get _endLocal =>
      _allDay ? _toDate.add(const Duration(days: 1)) : _toDate.add(Duration(minutes: _toMinutes));

  String? get _validation {
    final start = _startLocal;
    final end = _endLocal;
    if (!end.isAfter(start)) return 'The end must be after the start.';
    if (end.difference(start).inDays > _maxDays) return 'Time off can be at most a year at a time.';
    if (!end.isAfter(BookingTime.nowIn(widget.timeZone))) return 'That time has already passed.';
    return null;
  }

  Future<void> _pickDate({required bool from}) async {
    final today = BookingTime.todayIn(widget.timeZone);
    final initial = from ? _fromDate : _toDate;
    final first = from ? today : _fromDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: today.add(const Duration(days: _maxDays)),
      helpText: from ? 'Time off starts' : 'Time off ends',
    );
    if (picked == null || !mounted) return;
    final date = DateTime.utc(picked.year, picked.month, picked.day);
    setState(() {
      _error = null;
      if (from) {
        _fromDate = date;
        if (_toDate.isBefore(date)) _toDate = date;
      } else {
        _toDate = date;
      }
    });
  }

  Future<void> _pickTime({required bool from}) async {
    final picked = await showTimeWheelSheet(
      context,
      title: from ? 'Starts at' : 'Ends at',
      initialMinutes: from ? _fromMinutes : _toMinutes,
      minuteInterval: 15,
      allowMidnightEnd: !from,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _error = null;
      if (from) {
        _fromMinutes = picked;
      } else {
        _toMinutes = picked;
      }
    });
  }

  Future<void> _save() async {
    final problem = _validation;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final providerId = ref.read(currentProviderIdProvider);
    if (providerId == null) return;
    final start = BookingTime.instantOf(_startLocal, widget.timeZone);
    final end = BookingTime.instantOf(_endLocal, widget.timeZone);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final clashes = await ref
          .read(bookingRepositoryProvider)
          .activeBookingsBetween(providerId: providerId, start: start, end: end);
      if (!mounted) return;
      if (clashes.isNotEmpty && !await _confirmClashes(clashes)) {
        setState(() => _busy = false);
        return;
      }
      await ref.read(providerScheduleActionsProvider).addTimeOff(
            startsAt: start,
            endsAt: end,
            reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
          );
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.of(context).pop();
      context.showAppSnackBar('Time off added');
    } on BookingFailure catch (failure) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = failure.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = BookingFailure.from(e).message;
        });
      }
    }
  }

  Future<bool> _confirmClashes(List<Booking> clashes) async {
    final count = clashes.length;
    final listed = clashes.take(3).map((b) => '• ${Formatters.dateTimeShort(b.startsAtLocal)}, ${b.clientName}');
    final add = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(count == 1 ? 'You have an appointment then' : 'You have $count appointments then'),
        content: Text(
          '${listed.join('\n')}${count > 3 ? '\n…and ${count - 3} more' : ''}\n\n'
          "Adding time off won't cancel ${count == 1 ? 'it' : 'them'}. "
          'Cancel from your appointments if you need to.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Go back')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Add anyway')),
        ],
      ),
    );
    return add ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final year = BookingTime.todayIn(widget.timeZone).year;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add time off', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scheme.onSurface)),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              value: _allDay,
              onChanged: _busy ? null : (value) => setState(() => _allDay = value),
              contentPadding: EdgeInsets.zero,
              title: Text('All day', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: scheme.onSurface)),
            ),
            _FieldRow(
              label: 'From',
              date: Formatters.dateLong(_fromDate, currentYear: year),
              time: _allDay ? null : WorkingHoursRange.formatMinutes(_fromMinutes),
              onDate: _busy ? null : () => _pickDate(from: true),
              onTime: _busy ? null : () => _pickTime(from: true),
            ),
            const SizedBox(height: 10),
            _FieldRow(
              label: _allDay ? 'To (inclusive)' : 'To',
              date: Formatters.dateLong(_toDate, currentYear: year),
              time: _allDay ? null : WorkingHoursRange.formatMinutes(_toMinutes),
              onDate: _busy ? null : () => _pickDate(from: false),
              onTime: _busy ? null : () => _pickTime(from: false),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              enabled: !_busy,
              maxLength: _maxReasonLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. Holiday in Byron',
                helperText: 'Only you can see this.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.destructive),
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.onSurface,
                foregroundColor: scheme.surface,
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
              child: _busy
                  ? SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: scheme.surface))
                  : const Text('Add time off'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.date, required this.time, required this.onDate, required this.onTime});

  final String label;
  final String date;
  final String? time;
  final VoidCallback? onDate;
  final VoidCallback? onTime;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    Widget field(String text, IconData icon, VoidCallback? onTap, String semantic) => Semantics(
          button: true,
          label: '$label $semantic, $text',
          excludeSemantics: true,
          child: Material(
            color: scheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: scheme.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: scheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurface.withValues(alpha: 0.6)),
          ),
        ),
        Row(
          children: [
            Expanded(flex: 3, child: field(date, Icons.calendar_today_rounded, onDate, 'date')),
            if (time != null) ...[
              const SizedBox(width: 10),
              Expanded(flex: 2, child: field(time!, Icons.schedule_rounded, onTime, 'time')),
            ],
          ],
        ),
      ],
    );
  }
}
