import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../shared/bookings/models/booking_settings.dart';
import '../../../../shared/bookings/models/booking_time.dart';
import '../../../../shared/bookings/models/working_hours.dart';
import '../../../payments/controllers/payments_controllers.dart';
import '../../../payments/models/payments_setup.dart';
import '../../../provider_profiles/controllers/provider_services_controller.dart';
import '../../../provider_profiles/models/service_model.dart';
import '../../../provider_profiles/views/widgets/settings_widgets.dart';
import '../../../schedule/controllers/provider_schedule_controller.dart';
import '../../../schedule/models/time_off.dart';
import '../../../schedule/views/widgets/booking_rules_section.dart' show serviceAreaSummary;

/// The tools that run the business, grouped, each showing where it stands
/// (e.g. "Open 5 days a week", "No time off planned", "Card payments on").
/// A row whose state hasn't loaded shows just its title.
class BusinessManageSections extends ConsumerWidget {
  const BusinessManageSections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerId = ref.watch(currentProviderIdProvider);
    final settings = ref.watch(ownBookingSettingsProvider).value;
    final hours = ref.watch(ownWorkingHoursProvider).value;
    final timeOff = ref.watch(ownTimeOffProvider).value;
    final services = providerId == null ? null : ref.watch(providerServicesProvider(providerId)).value;
    final setup = ref.watch(paymentsSetupProvider).value;
    final timeZone = settings?.timeZone ?? BookingTime.defaultTimeZone;
    void push(AppRoute route) => context.pushNamed(route.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          title: 'Schedule',
          children: [
            SettingsTile(
              icon: Icons.schedule_rounded,
              title: 'Working hours',
              subtitle: workingHoursSummary(hours),
              iconColor: hours?.isEmpty == true ? AppTheme.warning : null,
              onTap: () => push(AppRoute.workingHours),
            ),
            SettingsTile(
              icon: Icons.beach_access_outlined,
              title: 'Time off',
              subtitle: timeOffSummary(timeOff, timeZone: timeZone, now: DateTime.now()),
              onTap: () => push(AppRoute.timeOff),
            ),
            SettingsTile(
              icon: Icons.rule_rounded,
              title: 'Booking rules',
              subtitle: bookingRulesSummary(settings),
              onTap: () => push(AppRoute.settings),
            ),
          ],
        ),
        SettingsSection(
          title: 'Services',
          children: [
            SettingsTile(
              icon: Icons.design_services_outlined,
              title: 'Services & pricing',
              subtitle: servicesSummary(services),
              iconColor: services?.isEmpty == true ? AppTheme.warning : null,
              // The profile tab opens on its Services list, where services
              // are added, edited and priced.
              onTap: () => context.goNamed(AppRoute.providerProfile.name),
            ),
            SettingsTile(
              icon: Icons.radar_outlined,
              title: 'Where you work',
              subtitle: settings == null ? null : serviceAreaSummary(settings),
              onTap: () => push(AppRoute.serviceArea),
            ),
          ],
        ),
        SettingsSection(
          title: 'Money',
          children: [
            SettingsTile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Payments & payouts',
              subtitle: paymentsSummary(setup),
              iconColor: setup?.status.needsProvider == true && setup?.status != PaymentsSetupStatus.notStarted
                  ? AppTheme.warning
                  : null,
              onTap: () => push(AppRoute.providerPayments),
            ),
            SettingsTile(
              icon: Icons.insights_rounded,
              title: 'Earnings',
              subtitle: 'Your share of each booking and your payouts',
              onTap: () => push(AppRoute.providerEarnings),
            ),
          ],
        ),
      ],
    );
  }
}

/// `Open 5 days a week`, or a warning when no hours are set.
String? workingHoursSummary(WeeklySchedule? hours) {
  if (hours == null) return null;
  if (hours.isEmpty) return "Not set. Clients can't book you yet";
  final days = [for (var weekday = 1; weekday <= 7; weekday++) if (hours.isOpenOn(weekday)) weekday].length;
  return days == 7 ? 'Open every day' : 'Open $days ${days == 1 ? 'day' : 'days'} a week';
}

/// The next time off in the provider's time zone (`Next: Sat 14 Nov`), or
/// when they're back if they're off now.
String? timeOffSummary(List<TimeOffBlock>? blocks, {required String timeZone, required DateTime now}) {
  if (blocks == null) return null;
  final upcoming = [for (final block in blocks) if (block.endsAt.isAfter(now)) block]
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  if (upcoming.isEmpty) return 'No time off planned';
  final next = upcoming.first;
  final more = upcoming.length > 1 ? ' · ${upcoming.length} planned' : '';
  if (next.covers(now)) {
    return 'Off now, back ${Formatters.dateTimeShort(BookingTime.wallClockOf(next.endsAt, timeZone))}$more';
  }
  return 'Next: ${Formatters.dateShort(BookingTime.wallClockOf(next.startsAt, timeZone))}$more';
}

/// `Clients book instantly · free to cancel until 24 h before`.
String? bookingRulesSummary(ProviderBookingSettings? settings) {
  if (settings == null) return null;
  final approval = settings.requiresApproval ? 'You approve each booking' : 'Clients book instantly';
  final window = settings.cancellationWindowHours;
  return '$approval · ${window == 0 ? 'free to cancel any time' : 'free to cancel until $window h before'}';
}

/// `4 services`, or a nudge to add the first one.
String? servicesSummary(List<ServiceModel>? services) {
  if (services == null) return null;
  if (services.isEmpty) return 'Add your first service';
  return services.length == 1 ? '1 service' : '${services.length} services';
}

/// Where card payments stand, in a few words.
String? paymentsSummary(PaymentsSetup? setup) {
  if (setup == null) return null;
  return switch (setup.status) {
    PaymentsSetupStatus.active || PaymentsSetupStatus.actionNeeded => 'Card payments on · paid out every Monday',
    PaymentsSetupStatus.notStarted => 'Not set up. Clients pay in cash',
    PaymentsSetupStatus.onboarding => 'Set-up not finished',
    PaymentsSetupStatus.verifying => 'Stripe is checking your details',
    PaymentsSetupStatus.restricted => 'Paused: Stripe needs details from you',
    PaymentsSetupStatus.rejected || PaymentsSetupStatus.closed => 'Card payments unavailable',
    PaymentsSetupStatus.unknown => null,
  };
}
