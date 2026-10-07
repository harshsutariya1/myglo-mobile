import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../../providers/provider_profiles/views/widgets/settings_widgets.dart' show PulsingDot;
import '../../../shared/bookings/controllers/booking_controllers.dart';
import '../../../shared/bookings/models/available_slot.dart';
import '../../../shared/bookings/models/booking_failure.dart';
import '../../../shared/bookings/models/booking_settings.dart';
import '../../../shared/bookings/models/booking_time.dart';
import '../../provider_profile/controllers/public_provider_profile_controller.dart';
import '../../provider_profile/views/widgets/provider_profile_header.dart';
import '../../provider_profile/views/widgets/section_states.dart';
import '../controllers/availability_controller.dart';
import '../controllers/booking_draft_controller.dart';
import '../controllers/service_selection_controller.dart';
import '../models/service_selection.dart';
import 'booking_flow_navigation.dart';
import 'widgets/booking_calendar.dart';
import 'widgets/booking_flow_scaffold.dart';
import 'widgets/time_slot_grid.dart';

/// Shown when a chosen time stops being available while the client is still
/// deciding (someone else booked it, or the provider changed their hours).
const String slotTakenMessage = 'That time is no longer available. Please pick another.';

/// Step 2: pick a day on the calendar, then a start time.
///
/// Times come from the provider's working hours, existing bookings (with the
/// provider's buffer), time off, minimum notice and booking window, all worked
/// out by the server. They update live: if the provider blocks out time or
/// someone else books while the client is deciding, the grid refreshes and a
/// chosen time that disappears is cleared with a notice.
class SelectDateTimeScreen extends ConsumerStatefulWidget {
  const SelectDateTimeScreen({super.key, required this.providerId});

  final String providerId;

  @override
  ConsumerState<SelectDateTimeScreen> createState() => _SelectDateTimeScreenState();
}

class _SelectDateTimeScreenState extends ConsumerState<SelectDateTimeScreen> {
  String get _providerId => widget.providerId;

  /// First day of the month on show; null until settings load.
  DateTime? _month;
  DateTime? _selectedDay;
  bool _autoAdvanced = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Coming back to the app after a while: availability may have moved on.
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(availableSlotsProvider));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  SlotRequest _requestFor(DateTime month, DateTime today, DateTime lastDay, ServiceSelection selection) {
    final monthStart = DateTime.utc(month.year, month.month);
    final monthEnd = DateTime.utc(month.year, month.month + 1, 0);
    return SlotRequest(
      providerId: _providerId,
      serviceIds: [for (final service in selection.services) service.id],
      from: monthStart.isBefore(today) ? today : monthStart,
      to: monthEnd.isAfter(lastDay) ? lastDay : monthEnd,
    );
  }

  void _changeMonth(DateTime current, int delta) {
    setState(() {
      _month = DateTime.utc(current.year, current.month + delta);
      _selectedDay = null;
    });
  }

  void _continue() => pushBookingStep(context, AppRoute.bookingLocation, _providerId);

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(serviceSelectionProvider(_providerId));
    final draft = ref.watch(bookingDraftProvider(_providerId));
    final settingsAsync = ref.watch(bookingSettingsProvider(_providerId));
    final provider = ref.watch(publicProviderProfileProvider(_providerId)).value;
    final slot = draft.slot;

    final footer = BookingFooter(
      actionLabel: 'Continue',
      onAction: slot == null ? null : _continue,
      summary: BookingFooterSummary(
        caption: slot == null
            ? '${selection.countLabel} · ${Formatters.duration(selection.totalMinutes)}'
            : Formatters.dateShort(slot.local),
        value: slot == null ? 'Pick a time' : Formatters.timeRange(slot.local, slot.localEnd(selection.totalMinutes)),
      ),
    );

    return BookingFlowScaffold(
      step: BookingStep.dateTime,
      title: 'Date & time',
      subtitle: provider == null ? null : providerDisplayName(provider),
      footer: selection.isEmpty ? null : footer,
      body: switch (settingsAsync) {
        _ when selection.isEmpty => const _NoServicesView(),
        AsyncValue(:final value?) when !value.acceptsBookings => const _CenteredState(
            child: SectionEmptyView(
              icon: Icons.event_busy_rounded,
              title: 'Not taking bookings right now',
              message: "This provider has paused online bookings. Check back soon, or contact them directly.",
            ),
          ),
        AsyncValue(:final value?) => _buildPicker(context, value, selection),
        AsyncData() => const _CenteredState(
            child: SectionEmptyView(
              icon: Icons.storefront_outlined,
              title: 'Provider unavailable',
              message: "This provider can't take bookings at the moment.",
            ),
          ),
        AsyncError(:final error) => _CenteredState(
            child: SectionErrorView(
              title: "Availability didn't load",
              message: describeLoadError(error, subject: "this provider's availability"),
              onRetry: () => ref.invalidate(bookingSettingsProvider(_providerId)),
            ),
          ),
        _ => const _PickerSkeleton(),
      },
    );
  }

  Widget _buildPicker(BuildContext context, ProviderBookingSettings settings, ServiceSelection selection) {
    final today = BookingTime.todayIn(settings.timeZone);
    final lastDay = settings.lastBookableDay(today);
    final month = _month ?? DateTime.utc(today.year, today.month);
    final request = _requestFor(month, today, lastDay, selection);
    final slotsAsync = ref.watch(availableSlotsProvider(request));
    final calendar = slotsAsync.value;
    final draft = ref.watch(bookingDraftProvider(_providerId));

    ref.listen(availableSlotsProvider(request), (previous, next) {
      final loaded = next.value;
      if (loaded == null) return;
      // Can fire while building, so act after the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // A chosen time in this month that's no longer offered was just taken
        // (or the provider changed their availability).
        final chosen = ref.read(bookingDraftProvider(_providerId)).slot;
        if (chosen != null &&
            !chosen.day.isBefore(request.from) &&
            !chosen.day.isAfter(request.to) &&
            !loaded.contains(chosen)) {
          ref.read(bookingDraftProvider(_providerId).notifier).clearSlot();
          context.showAppSnackBar(slotTakenMessage, isError: true);
        }
        // Late in the month with nothing left: open on next month instead.
        final nextMonth = DateTime.utc(month.year, month.month + 1);
        if (!_autoAdvanced && _month == null && loaded.isEmpty && !nextMonth.isAfter(lastDay)) {
          setState(() {
            _autoAdvanced = true;
            _month = nextMonth;
          });
        }
      });
    });

    final chosenDayInMonth = draft.slot?.day;
    final selectedDay = _selectedDay ??
        (chosenDayInMonth != null && chosenDayInMonth.month == month.month && chosenDayInMonth.year == month.year
            ? chosenDayInMonth
            : calendar?.firstDayFrom(request.from));
    final daySlots = selectedDay == null ? const <AvailableSlot>[] : calendar?.on(selectedDay) ?? const [];
    final offset = daySlots.isNotEmpty ? daySlots.first.utcOffset : null;

    return RefreshIndicator(
      color: context.colorScheme.primary,
      onRefresh: () async {
        ref.invalidate(availableSlotsProvider(request));
        try {
          await ref.read(availableSlotsProvider(request).future);
        } catch (_) {
          // Shown inline below.
        }
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _SelectionSummary(selection: selection, onEdit: () => popBookingFlowTo(context, AppRoute.selectServices)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.colorScheme.onSurface.withValues(alpha: 0.08)),
            ),
            child: BookingCalendar(
              month: month,
              today: today,
              lastDay: lastDay,
              selectedDay: selectedDay,
              loading: calendar == null,
              hasSlots: (day) => calendar?.hasSlotsOn(day) ?? false,
              onSelectDay: (day) => setState(() => _selectedDay = day),
              onChangeMonth: (delta) => _changeMonth(month, delta),
            ),
          ),
          const SizedBox(height: 22),
          _DayHeader(
            day: selectedDay,
            timeZone: settings.timeZone,
            offset: offset,
            count: daySlots.length,
            refreshing: slotsAsync.isLoading && calendar != null,
          ),
          const SizedBox(height: 12),
          _buildTimes(context, slotsAsync, calendar, selectedDay, daySlots, selection, month, lastDay, request),
        ],
      ),
    );
  }

  Widget _buildTimes(
    BuildContext context,
    AsyncValue<SlotCalendar> slotsAsync,
    SlotCalendar? calendar,
    DateTime? selectedDay,
    List<AvailableSlot> daySlots,
    ServiceSelection selection,
    DateTime month,
    DateTime lastDay,
    SlotRequest request,
  ) {
    if (calendar == null) {
      if (slotsAsync case AsyncError(:final error)) {
        return SectionErrorView(
          title: "Times didn't load",
          message: BookingFailure.from(error).code == BookingFailureCode.unknown
              ? describeLoadError(error, subject: 'the available times')
              : BookingFailure.from(error).message,
          onRetry: () => ref.invalidate(availableSlotsProvider(request)),
        );
      }
      return const Shimmer(child: TimeSlotGridSkeleton());
    }

    if (daySlots.isNotEmpty) {
      return TimeSlotGrid(
        slots: daySlots,
        selected: ref.watch(bookingDraftProvider(_providerId)).slot,
        durationMinutes: selection.totalMinutes,
        onSelected: (slot) => ref.read(bookingDraftProvider(_providerId).notifier).selectSlot(slot),
      );
    }

    final nextMonth = DateTime.utc(month.year, month.month + 1);
    final canGoForward = !nextMonth.isAfter(lastDay);
    if (calendar.isEmpty) {
      return _NoTimes(
        icon: Icons.event_busy_rounded,
        title: 'No availability in ${Formatters.monthYear(month)}',
        message: canGoForward
            ? 'Everything is booked or closed this month. Try next month.'
            : "This provider hasn't any free times left in their booking window.",
        actionLabel: canGoForward ? 'View ${Formatters.monthYear(nextMonth)}' : null,
        onAction: canGoForward ? () => _changeMonth(month, 1) : null,
        footer: _HoursHint(providerId: _providerId),
      );
    }

    final nextDay = selectedDay == null ? null : calendar.firstDayFrom(selectedDay.add(const Duration(days: 1)));
    return _NoTimes(
      icon: Icons.free_cancellation_outlined,
      title: selectedDay == null ? 'Choose a day' : 'No times on ${Formatters.weekdayLong(selectedDay)}',
      message: 'This day is fully booked or the provider is closed.',
      actionLabel: nextDay == null ? null : 'Next available: ${Formatters.dateShort(nextDay)}',
      onAction: nextDay == null ? null : () => setState(() => _selectedDay = nextDay),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  const _SelectionSummary({required this.selection, required this.onEdit});

  final ServiceSelection selection;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final names = selection.services.map((service) => service.name).join(', ');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
            child: Icon(Icons.spa_outlined, size: 18, color: scheme.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  names,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: scheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  '${Formatters.duration(selection.totalMinutes)} · ${Formatters.audCents(selection.totalCents)}',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              foregroundColor: scheme.secondary,
              textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.timeZone,
    required this.offset,
    required this.count,
    required this.refreshing,
  });

  final DateTime? day;
  final String timeZone;
  final Duration? offset;
  final int count;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  day == null ? 'Available times' : Formatters.dateLong(day!),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: scheme.onSurface),
                ),
              ),
            ),
            if (refreshing)
              SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary))
            else if (count > 0)
              Text(
                count == 1 ? '1 time' : '$count times',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: muted),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const PulsingDot(color: AppTheme.success, size: 6),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Live availability · times in ${BookingTime.label(timeZone, offset: offset)}',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: muted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NoTimes extends StatelessWidget {
  const _NoTimes({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: scheme.secondary),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: scheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.6)),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary.withValues(alpha: 0.14),
                foregroundColor: scheme.onSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              child: Text(actionLabel!),
            ),
          ],
          ?footer,
        ],
      ),
    );
  }
}

/// Explains an empty calendar when the provider hasn't published hours yet.
class _HoursHint extends ConsumerWidget {
  const _HoursHint({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hours = ref.watch(workingHoursProvider(providerId)).value;
    if (hours == null || !hours.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        "This provider hasn't published their opening hours yet.",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colorScheme.secondary),
      ),
    );
  }
}

class _NoServicesView extends StatelessWidget {
  const _NoServicesView();

  @override
  Widget build(BuildContext context) {
    return _CenteredState(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SectionEmptyView(
            icon: Icons.content_cut_rounded,
            title: 'Choose your services first',
            message: 'Pick at least one service so we can find times that fit.',
          ),
          FilledButton(
            onPressed: () => popBookingFlowTo(context, AppRoute.selectServices),
            child: const Text('Choose services'),
          ),
        ],
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(child: SingleChildScrollView(child: child));
}

class _PickerSkeleton extends StatelessWidget {
  const _PickerSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          const SkeletonBox(height: 60, borderRadius: 18),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) => SkeletonBox(
              height: math.min(380, constraints.maxWidth + 60),
              borderRadius: 24,
            ),
          ),
          const SizedBox(height: 22),
          const SkeletonText(style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800), widthFactor: 0.5),
          const SizedBox(height: 12),
          const TimeSlotGridSkeleton(),
        ],
      ),
    );
  }
}
