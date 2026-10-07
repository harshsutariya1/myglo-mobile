import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/snackbar_utils.dart';
import '../../../../shared/bookings/models/booking_failure.dart';
import '../../../../shared/bookings/models/booking_settings.dart';
import '../../../../shared/bookings/models/booking_time.dart';
import '../../../provider_profiles/views/widgets/settings_widgets.dart';
import '../../controllers/provider_schedule_controller.dart';
import '../time_off_screen.dart';
import 'schedule_widgets.dart';

/// Wording for each booking rule's values.
abstract final class BookingRuleLabels {
  static String slotInterval(int minutes) => minutes == 60 ? 'Every hour' : 'Every $minutes minutes';

  static String buffer(int minutes) => minutes == 0 ? 'No buffer' : '$minutes min between bookings';

  static String notice(int minutes) {
    if (minutes == 0) return 'No minimum';
    if (minutes < 60) return '$minutes minutes ahead';
    if (minutes % 1440 == 0) return minutes == 1440 ? '1 day ahead' : '${minutes ~/ 1440} days ahead';
    final hours = minutes / 60;
    final text = hours == hours.roundToDouble() ? '${hours.round()}' : hours.toStringAsFixed(1);
    return '$text ${hours == 1 ? 'hour' : 'hours'} ahead';
  }

  static String bookingWindow(int days) => switch (days) {
        7 => '1 week ahead',
        14 => '2 weeks ahead',
        30 => '1 month ahead',
        60 => '2 months ahead',
        90 => '3 months ahead',
        180 => '6 months ahead',
        365 => '1 year ahead',
        _ => '$days days ahead',
      };

  static String cancellationWindow(int hours) {
    if (hours == 0) return 'Free until the start time';
    if (hours % 24 == 0) return 'Free until ${hours == 24 ? '1 day' : '${hours ~/ 24} days'} before';
    return 'Free until $hours ${hours == 1 ? 'hour' : 'hours'} before';
  }

  static String cancellationFee(int percent) => switch (percent) {
        0 => 'No fee',
        100 => 'Full price',
        _ => '$percent% of the booking',
      };

  /// The fee rule's current value: it only ever applies to bookings paid in
  /// the app, never to cash.
  static String lateFeeSummary(int percent) =>
      percent == 0 ? 'No fee' : '${cancellationFee(percent)} · paid in app only';
}

/// The "Availability & bookings" settings: live booking rules, each saved as
/// soon as it changes.
class BookingRulesSection extends ConsumerStatefulWidget {
  const BookingRulesSection({super.key});

  @override
  ConsumerState<BookingRulesSection> createState() => _BookingRulesSectionState();
}

class _BookingRulesSectionState extends ConsumerState<BookingRulesSection> {
  /// The rule being saved, so its row can show progress.
  String? _saving;

  static const _slotIntervals = [5, 10, 15, 20, 30, 45, 60];
  static const _buffers = [0, 5, 10, 15, 20, 30, 45, 60];
  static const _notices = [0, 30, 60, 120, 240, 720, 1440, 2880];
  static const _windows = [14, 30, 60, 90, 180, 365];
  static const _cancellationWindows = [0, 2, 6, 12, 24, 48, 72];
  static const _cancellationFees = [0, 25, 50, 100];

  Future<void> _save(String column, Object? value) async {
    setState(() => _saving = column);
    try {
      await ref.read(providerScheduleActionsProvider).updateSettings({column: value});
    } on BookingFailure catch (failure) {
      if (mounted) context.showAppSnackBar(failure.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  Future<void> _pick({
    required String column,
    required String title,
    String? message,
    required List<int> options,
    required int current,
    required String Function(int) label,
    String? Function(int)? detail,
  }) async {
    final values = {...options, current}.toList()..sort();
    final picked = await showChoiceSheet<int>(
      context,
      title: title,
      message: message,
      selected: current,
      choices: [for (final value in values) (value: value, label: label(value), detail: detail?.call(value))],
    );
    if (picked != null && picked != current && mounted) await _save(column, picked);
  }

  Widget? _progress(String column) => _saving == column
      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
      : null;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(ownBookingSettingsProvider).value;
    final hours = ref.watch(ownWorkingHoursProvider);
    final timeOff = ref.watch(ownTimeOffProvider).value;
    final timeZone = settings?.timeZone ?? BookingTime.defaultTimeZone;
    final enabled = settings != null && _saving == null;

    final hoursSummary = switch (hours) {
      AsyncData(:final value) => value.summary ?? "Not set. Clients can't book you yet",
      AsyncError() => "Couldn't load your hours",
      _ => null,
    };

    return SettingsSection(
      title: 'Availability & bookings',
      footer: 'Times are in ${BookingTime.label(timeZone)}. Queensland has no daylight saving.',
      children: [
        SettingsTile(
          icon: Icons.schedule_rounded,
          title: 'Working hours',
          subtitle: hoursSummary,
          iconColor: hours.value?.isEmpty == true ? AppTheme.warning : null,
          onTap: () => context.pushNamed(AppRoute.workingHours.name),
        ),
        SettingsTile(
          icon: Icons.event_busy_outlined,
          title: 'Time off',
          subtitle: switch (timeOff) {
            null => null,
            [] => 'None planned',
            [final next, ...] => 'Next: ${describeTimeOff(next, timeZone).title}',
          },
          onTap: () => context.pushNamed(AppRoute.timeOff.name),
        ),
        SettingsTile(
          icon: Icons.how_to_reg_outlined,
          title: 'Approve each booking',
          subtitle: settings == null
              ? null
              : settings.requiresApproval
                  ? 'Every booking waits for you to accept'
                  : 'Cash bookings wait for you; ones paid in the app confirm instantly',
          onTap: enabled ? () => _save('requires_approval', !settings.requiresApproval) : null,
          trailing: _progress('requires_approval') ??
              Switch.adaptive(
                value: settings?.requiresApproval ?? false,
                onChanged: enabled ? (value) => _save('requires_approval', value) : null,
              ),
        ),
        _RuleTile(
          icon: Icons.av_timer_rounded,
          title: 'Start times',
          value: settings == null ? null : BookingRuleLabels.slotInterval(settings.slotIntervalMinutes),
          progress: _progress('slot_interval_minutes'),
          onTap: !enabled
              ? null
              : () => _pick(
                    column: 'slot_interval_minutes',
                    title: 'Offer start times',
                    message: 'How often appointments can start, e.g. 9:00, 9:15, 9:30.',
                    options: _slotIntervals,
                    current: settings.slotIntervalMinutes,
                    label: BookingRuleLabels.slotInterval,
                  ),
        ),
        _RuleTile(
          icon: Icons.more_time_rounded,
          title: 'Buffer between bookings',
          value: settings == null ? null : BookingRuleLabels.buffer(settings.bufferMinutes),
          progress: _progress('buffer_minutes'),
          onTap: !enabled
              ? null
              : () => _pick(
                    column: 'buffer_minutes',
                    title: 'Buffer between bookings',
                    message: 'Time kept free after each appointment to clean up, rest or travel.',
                    options: _buffers,
                    current: settings.bufferMinutes,
                    label: (minutes) => minutes == 0 ? 'No buffer' : '$minutes minutes',
                  ),
        ),
        _RuleTile(
          icon: Icons.notification_important_outlined,
          title: 'Minimum notice',
          value: settings == null ? null : BookingRuleLabels.notice(settings.minNoticeMinutes),
          progress: _progress('min_notice_minutes'),
          onTap: !enabled
              ? null
              : () => _pick(
                    column: 'min_notice_minutes',
                    title: 'Minimum notice',
                    message: 'How far ahead clients must book.',
                    options: _notices,
                    current: settings.minNoticeMinutes,
                    label: BookingRuleLabels.notice,
                  ),
        ),
        _RuleTile(
          icon: Icons.date_range_outlined,
          title: 'Booking window',
          value: settings == null ? null : BookingRuleLabels.bookingWindow(settings.maxAdvanceDays),
          progress: _progress('max_advance_days'),
          onTap: !enabled
              ? null
              : () => _pick(
                    column: 'max_advance_days',
                    title: 'Booking window',
                    message: 'How far into the future clients can book.',
                    options: _windows,
                    current: settings.maxAdvanceDays,
                    label: BookingRuleLabels.bookingWindow,
                  ),
        ),
        _RuleTile(
          icon: Icons.event_available_outlined,
          title: 'Free cancellation',
          value: settings == null ? null : BookingRuleLabels.cancellationWindow(settings.cancellationWindowHours),
          progress: _progress('cancellation_window_hours'),
          onTap: !enabled
              ? null
              : () => _pick(
                    column: 'cancellation_window_hours',
                    title: 'Free cancellation',
                    message: 'Clients can cancel for free until this point. Later cancellations are marked as late. '
                        'Changes apply to new bookings only.',
                    options: _cancellationWindows,
                    current: settings.cancellationWindowHours,
                    label: BookingRuleLabels.cancellationWindow,
                  ),
        ),
        _RuleTile(
          icon: Icons.money_off_csred_outlined,
          title: 'Late cancellation fee',
          value: settings == null ? null : BookingRuleLabels.lateFeeSummary(settings.cancellationFeePercent),
          progress: _progress('cancellation_fee_percent'),
          onTap: !enabled
              ? null
              : () => _pick(
                    column: 'cancellation_fee_percent',
                    title: 'Late cancellation fee',
                    message: 'Owed for late cancellations and no-shows on bookings paid in the app. '
                        'Cash bookings never have a fee. Changes apply to new bookings only.',
                    options: _cancellationFees,
                    current: settings.cancellationFeePercent,
                    label: BookingRuleLabels.cancellationFee,
                  ),
        ),
      ],
    );
  }
}

/// A rule with its current value under the title.
class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.icon, required this.title, required this.value, required this.onTap, this.progress});

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final Widget? progress;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(icon: icon, title: title, subtitle: value, onTap: onTap, trailing: progress);
  }
}

/// Short summary of where a provider works, for the settings row.
String serviceAreaSummary(ProviderBookingSettings settings) {
  final parts = [
    if (settings.offersStudio) 'At your studio',
    if (settings.offersMobile)
      settings.travelRadiusKm == null ? 'Mobile visits' : 'Mobile up to ${settings.travelRadiusKm!.round()} km',
  ];
  return parts.join(' · ');
}
