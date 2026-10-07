import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myglo/src/core/routing/app_router.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/customers/booking/controllers/availability_controller.dart';
import 'package:myglo/src/features/customers/booking/controllers/booking_draft_controller.dart';
import 'package:myglo/src/features/customers/booking/controllers/service_selection_controller.dart';
import 'package:myglo/src/features/customers/booking/views/select_date_time_screen.dart';
import 'package:myglo/src/features/customers/provider_profile/controllers/public_provider_profile_controller.dart';
import 'package:myglo/src/features/providers/provider_profiles/controllers/provider_services_controller.dart';
import 'package:myglo/src/features/providers/provider_profiles/models/service_model.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:myglo/src/features/shared/bookings/controllers/booking_controllers.dart';
import 'package:myglo/src/features/shared/bookings/models/available_slot.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_settings.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_time.dart';
import 'package:myglo/src/features/shared/bookings/models/working_hours.dart';

const _providerId = 'prov-1';
const _nextStep = 'Location step';

/// Tomorrow on the Gold Coast at [hour]:[minute].
AvailableSlot _tomorrowAt(int hour, [int minute = 0]) {
  final day = BookingTime.todayIn(BookingTime.defaultTimeZone).add(const Duration(days: 1));
  final local = DateTime.utc(day.year, day.month, day.day, hour, minute);
  return AvailableSlot(startsAt: BookingTime.instantOf(local, BookingTime.defaultTimeZone), local: local);
}

/// Stands in for the server: whatever is in [slots] when asked.
class _Availability {
  List<AvailableSlot> slots = [_tomorrowAt(9), _tomorrowAt(9, 30), _tomorrowAt(14)];

  SlotCalendar serve(SlotRequest request) => SlotCalendar(
        slots.where((slot) => !slot.day.isBefore(request.from) && !slot.day.isAfter(request.to)),
      );
}

Future<ProviderContainer> _pump(WidgetTester tester, _Availability availability) async {
  // A phone screen (390 × 844), so the times sit where they would on a device.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/time',
    routes: [
      GoRoute(
        path: '/time',
        builder: (_, _) => const SelectDateTimeScreen(providerId: _providerId),
      ),
      GoRoute(
        path: '/provider/:id/book/time/location',
        name: AppRoute.bookingLocation.name,
        builder: (_, _) => const Scaffold(body: Text(_nextStep)),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        publicProviderProfileProvider(_providerId).overrideWith(
          (ref) => const ProfileModel(id: _providerId, role: UserRole.provider, providerName: 'Glow Studio'),
        ),
        providerServicesProvider(_providerId).overrideWith(
          (ref) => [
            ServiceModel(
              id: 'svc-1',
              providerId: _providerId,
              name: 'Lash lift',
              description: '',
              price: 85,
              durationMinutes: 70,
              createdAt: DateTime.utc(2026, 9, 1),
            ),
          ],
        ),
        bookingSettingsProvider(_providerId).overrideWith(
          (ref) => Stream.value(const ProviderBookingSettings(providerId: _providerId)),
        ),
        workingHoursProvider(_providerId).overrideWith(
          (ref) async => WeeklySchedule([
            for (var day = 1; day <= 7; day++)
              WorkingHoursRange(weekday: day, opensMinutes: 9 * 60, closesMinutes: 17 * 60),
          ]),
        ),
        availableSlotsProvider.overrideWith((ref, request) async => availability.serve(request)),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
        // Keeps the live-availability dot still so frames settle.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
  final container = ProviderScope.containerOf(tester.element(find.byType(SelectDateTimeScreen)));
  container.read(selectedServiceIdsProvider(_providerId).notifier).select('svc-1');
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('opens on the first day with times, grouped by part of the day', (tester) async {
    await _pump(tester, _Availability());

    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Afternoon'), findsOneWidget);
    expect(find.text('9:00 am'), findsOneWidget);
    expect(find.text('9:30 am'), findsOneWidget);
    expect(find.text('2:00 pm'), findsOneWidget);
    expect(find.text('Pick a time'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue')).onPressed, isNull);
  });

  testWidgets('picking a time shows the appointment and continues to the location', (tester) async {
    final container = await _pump(tester, _Availability());

    await tester.tap(find.text('9:30 am'));
    await tester.pumpAndSettle();

    expect(find.text('9:30 am – 10:40 am'), findsOneWidget);
    expect(container.read(bookingDraftProvider(_providerId)).slot, _tomorrowAt(9, 30));

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text(_nextStep), findsOneWidget);
  });

  testWidgets('a chosen time that is taken meanwhile is cleared with a warning', (tester) async {
    final availability = _Availability();
    final container = await _pump(tester, availability);
    await tester.tap(find.text('9:30 am'));
    await tester.pumpAndSettle();

    // Someone else books 9:30 and the live signal makes the screen refetch.
    availability.slots = [_tomorrowAt(9), _tomorrowAt(14)];
    container.invalidate(availableSlotsProvider);
    await tester.pumpAndSettle();

    expect(container.read(bookingDraftProvider(_providerId)).slot, isNull);
    expect(find.text(slotTakenMessage), findsOneWidget);
    expect(find.text('9:30 am'), findsNothing);
    expect(find.text('Pick a time'), findsOneWidget);
  });
}
