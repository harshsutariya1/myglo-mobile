import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myglo/src/core/config/app_config.dart';
import 'package:myglo/src/core/platform/contact_launcher.dart';
import 'package:myglo/src/core/routing/app_router.dart';
import 'package:myglo/src/core/routing/app_router_guard.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/providers/business_tools/controllers/contacts_controllers.dart';
import 'package:myglo/src/features/providers/business_tools/models/contacts_repository.dart';
import 'package:myglo/src/features/providers/business_tools/models/provider_contact.dart';
import 'package:myglo/src/features/providers/business_tools/views/contacts_screen.dart';
import 'package:myglo/src/features/providers/business_tools/views/widgets/client_contact_sheet.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:myglo/src/features/shared/bookings/controllers/booking_controllers.dart';
import 'package:myglo/src/features/shared/bookings/models/booking.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_enums.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_repository.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_time.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/booking_fixtures.dart';

final _providerUser = User(
  id: 'prov-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
);

Map<String, dynamic> _row({
  String clientId = 'client-1',
  String name = 'Michelle Zhang',
  String phone = '0412 345 678',
  String? email,
  int bookings = 3,
  int completed = 2,
  int upcoming = 1,
  Object paid = 23000,
  String lastStartsAt = '2026-10-20T23:30:00+00:00',
  String? lastVisit = '2026-10-08T09:30:00',
  String? next = '2026-10-21T09:30:00',
}) =>
    {
      'client_id': clientId,
      'client_name': name,
      'client_avatar_url': null,
      'client_phone': phone,
      'client_email': email,
      'time_zone': 'Australia/Brisbane',
      'booking_count': bookings,
      'completed_count': completed,
      'upcoming_count': upcoming,
      'total_paid_cents': paid,
      'first_booked_at': '2026-03-02T01:00:00+00:00',
      'last_starts_at': lastStartsAt,
      'last_visit_local': lastVisit,
      'next_starts_at_local': next,
    };

final _michelle = ProviderContact.fromJson(_row());
final _sam = ProviderContact.fromJson(_row(
  clientId: 'client-2',
  name: 'Sam Carter',
  phone: '0400 111 222',
  bookings: 1,
  completed: 1,
  upcoming: 0,
  paid: 8500,
  lastStartsAt: '2026-09-01T00:00:00+00:00',
  lastVisit: '2026-09-01T10:00:00',
  next: null,
));

/// Serves [contacts] in pages, filtering by name like the RPC does.
class _FakeContacts implements ContactsRepository {
  _FakeContacts(this.contacts, {this.failures = 0});

  final List<ProviderContact> contacts;
  int failures;
  final calls = <({String? search, String? after, int limit})>[];

  @override
  Future<List<ProviderContact>> list({String? search, ProviderContact? after, required int limit}) async {
    calls.add((search: search, after: after?.clientId, limit: limit));
    if (failures > 0) {
      failures--;
      throw const PostgrestException(message: 'boom', code: '500');
    }
    final query = (search ?? '').toLowerCase();
    final matching = contacts.where((c) => c.name.toLowerCase().contains(query)).toList();
    final start = after == null ? 0 : matching.indexWhere((c) => c.clientId == after.clientId) + 1;
    return matching.skip(start).take(limit).toList();
  }

  @override
  Future<ProviderContact?> get(String clientId) async =>
      contacts.where((c) => c.clientId == clientId).firstOrNull;

  @override
  Future<int> count() async => contacts.length;
}

/// Michelle's bookings: one upcoming, one completed and paid, one cancelled.
class _FakeBookings implements BookingRepository {
  final requests = <({String providerId, String clientId, String? after})>[];

  static final bookings = [
    sampleBooking(id: 'b-next', startsAt: DateTime.utc(2027, 1, 20, 23, 30)),
    sampleBooking(
      id: 'b-done',
      status: BookingStatus.completed,
      paymentStatus: PaymentStatus.paid,
      startsAt: DateTime.utc(2026, 10, 7, 23, 30),
    ),
    sampleBooking(
      id: 'b-cancelled',
      status: BookingStatus.cancelled,
      paymentStatus: PaymentStatus.voided,
      startsAt: DateTime.utc(2026, 9, 1, 0, 0),
    ),
  ];

  @override
  Future<List<Booking>> listWithClient({
    required String providerId,
    required String clientId,
    Booking? after,
    int limit = 20,
  }) async {
    requests.add((providerId: providerId, clientId: clientId, after: after?.id));
    return clientId == 'client-1' ? bookings : const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

/// Records what was opened; [opens] says whether an app handled it.
class _FakeLauncher implements ContactLauncher {
  _FakeLauncher({this.opens = true});

  final bool opens;
  final launched = <String>[];

  @override
  Future<bool> call(String phone) async {
    launched.add('call:$phone');
    return opens;
  }

  @override
  Future<bool> message(String phone) async {
    launched.add('message:$phone');
    return opens;
  }

  @override
  Future<bool> email(String address) async {
    launched.add('email:$address');
    return opens;
  }
}

List<Override> _overrides(
  ContactsRepository contacts, {
  BookingRepository? bookings,
  Stream<int>? changes,
  ContactLauncher? launcher,
}) =>
    [
      userProfileProvider.overrideWith(
        (ref) async => AppUserProfile(
          rawUser: _providerUser,
          role: UserRole.provider,
          profile: const ProfileModel(id: 'prov-1', role: UserRole.provider, providerName: 'Glow Studio'),
        ),
      ),
      bookingChangesProvider.overrideWith((ref) => changes ?? const Stream.empty()),
      contactsRepositoryProvider.overrideWithValue(contacts),
      bookingRepositoryProvider.overrideWithValue(bookings ?? _FakeBookings()),
      contactLauncherProvider.overrideWithValue(launcher ?? _FakeLauncher()),
    ];

Future<void> _pump(WidgetTester tester, List<Override> overrides) async {
  // A typical phone (390 × 844 points).
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: AppRoute.providerContacts.path,
    routes: [
      GoRoute(
        path: AppRoute.providerContacts.path,
        name: AppRoute.providerContacts.name,
        builder: (context, state) => const ContactsScreen(),
      ),
      GoRoute(
        path: AppRoute.providerBookingDetail.path,
        name: AppRoute.providerBookingDetail.name,
        builder: (context, state) => Scaffold(
          appBar: AppBar(),
          body: Text('Detail ${state.pathParameters['bookingId']}'),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: overrides,
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        // Keeps the shimmer still so frames settle.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Texts copied to the clipboard during the test.
List<String> _watchClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return copied;
}

int _thisYear() => BookingTime.todayIn(BookingTime.defaultTimeZone).year;

void main() {
  group('ProviderContact', () {
    test('reads the RPC row: instants, provider-local wall clocks and bigint totals', () {
      expect(_michelle.clientId, 'client-1');
      expect(_michelle.bookingCount, 3);
      expect(_michelle.completedCount, 2);
      expect(_michelle.upcomingCount, 1);
      expect(_michelle.totalPaidCents, 23000);
      expect(_michelle.firstBookedAt, DateTime.utc(2026, 3, 2, 1));
      expect(_michelle.lastStartsAt, DateTime.utc(2026, 10, 20, 23, 30));
      // Wall clocks keep their fields whatever the device's zone.
      expect(_michelle.lastVisitLocal, DateTime.utc(2026, 10, 8, 9, 30));
      expect(_michelle.nextStartsAtLocal, DateTime.utc(2026, 10, 21, 9, 30));
      expect(_michelle.hasUpcoming, isTrue);
      expect(_sam.hasUpcoming, isFalse);
    });

    test('keeps the email only when the client made it public', () {
      expect(_michelle.email, isNull);
      expect(ProviderContact.fromJson(_row(email: ' mia@example.com ')).email, 'mia@example.com');
      expect(ProviderContact.fromJson(_row(email: '')).email, isNull);
    });

    test('tolerates missing totals and a blank name', () {
      final contact = ProviderContact.fromJson({
        'client_id': 'c',
        'client_name': '  ',
        'client_phone': null,
        'first_booked_at': '2026-03-02T01:00:00Z',
        'last_starts_at': '2026-03-02T01:00:00Z',
      });
      expect(contact.displayName, 'Client');
      expect(contact.phone, isEmpty);
      expect(contact.timeZone, BookingTime.defaultTimeZone);
      expect(contact.bookingCount, 0);
      expect(contact.totalPaidCents, 0);
      expect(contact.lastVisitLocal, isNull);
      expect(contact.nextStartsAtLocal, isNull);
    });
  });

  group('contact copy', () {
    test('dates add the year only outside the current one', () {
      final date = DateTime.utc(2026, 10, 21, 9, 30);
      expect(contactDate(date, 2026), 'Wed 21 Oct');
      expect(contactDate(date, 2026, withTime: true), 'Wed 21 Oct, 9:30 am');
      expect(contactDate(date, 2027), '21 Oct 2026');
    });

    test('visit counts read naturally', () {
      expect(visitCount(0), 'No visits');
      expect(visitCount(1), '1 visit');
      expect(visitCount(12), '12 visits');
    });

    test("what's next comes first, then the last visit", () {
      expect(contactActivity(_michelle).upcoming, isTrue);
      expect(contactActivity(_michelle).text, startsWith('Next · '));
      expect(contactActivity(_sam).text, startsWith('Last visit '));
      final never = ProviderContact.fromJson(_row(completed: 0, upcoming: 0, lastVisit: null, next: null));
      expect(contactActivity(never).text, 'No visits yet');
    });
  });

  test('phone links keep only what can be dialled', () {
    expect(UrlContactLauncher.phoneUri('tel', '0412 345 678').toString(), 'tel:0412345678');
    expect(UrlContactLauncher.phoneUri('sms', '+61 (412) 345-678').toString(), 'sms:+61412345678');
    expect(UrlContactLauncher.phoneUri('tel', ' - '), isNull);
  });

  test('contacts are provider-only', () {
    expect(isProviderOnlyPath(AppRoute.providerContacts.path), isTrue);
    expect(isClientOnlyPath(AppRoute.providerContacts.path), isFalse);
  });

  group('Contacts screen', () {
    testWidgets('lists clients with what is next, visits and what they paid', (tester) async {
      await _pump(tester, _overrides(_FakeContacts([_michelle, _sam])));

      expect(find.text('2 clients · Most recent first'), findsOneWidget);
      expect(find.text('Michelle Zhang'), findsOneWidget);
      expect(find.text('Next · ${contactDate(DateTime.utc(2026, 10, 21, 9, 30), _thisYear(), withTime: true)}'),
          findsOneWidget);
      expect(find.text(r'$230'), findsOneWidget);
      expect(find.text('2 visits'), findsOneWidget);
      expect(find.text('Sam Carter'), findsOneWidget);
      expect(find.text('Last visit ${contactDate(DateTime.utc(2026, 9, 1, 10), _thisYear())}'), findsOneWidget);
      expect(find.text(r'$85'), findsOneWidget);
      expect(find.text('1 visit'), findsOneWidget);
      // Most recent first, as the server ordered them.
      expect(tester.getTopLeft(find.text('Michelle Zhang')).dy, lessThan(tester.getTopLeft(find.text('Sam Carter')).dy));
    });

    testWidgets('a provider nobody has booked yet sees an empty state, without search', (tester) async {
      await _pump(tester, _overrides(_FakeContacts([])));

      expect(find.text('No clients yet'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('a failed load shows an inline error that can be retried', (tester) async {
      final contacts = _FakeContacts([_michelle], failures: 1);
      await _pump(tester, _overrides(contacts));

      expect(find.text("Contacts didn't load"), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text("Contacts didn't load"), findsNothing);
      expect(find.text('Michelle Zhang'), findsOneWidget);
    });

    testWidgets('search waits for typing to pause, then filters on the server', (tester) async {
      final contacts = _FakeContacts([_michelle, _sam]);
      await _pump(tester, _overrides(contacts));
      contacts.calls.clear();

      await tester.enterText(find.byType(TextField), 'sa');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'sam ');
      await tester.pump(AppConfig.contactsSearchDebounce);
      await tester.pumpAndSettle();

      // One request, for the final (trimmed) text.
      expect(contacts.calls.map((c) => c.search), ['sam']);
      expect(find.text('Sam Carter'), findsOneWidget);
      expect(find.text('Michelle Zhang'), findsNothing);
      expect(find.text('2 clients · Most recent first'), findsNothing);

      await tester.enterText(find.byType(TextField), 'nobody');
      await tester.pump(AppConfig.contactsSearchDebounce);
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Michelle Zhang'), findsOneWidget);
      expect(find.text('Sam Carter'), findsOneWidget);
    });

    testWidgets('scrolling down loads the next page after the last contact', (tester) async {
      final many = [
        for (var i = 0; i < AppConfig.contactsPageSize + 5; i++)
          ProviderContact.fromJson(_row(
            clientId: 'c-$i',
            name: 'Client ${i.toString().padLeft(2, '0')}',
            lastStartsAt: DateTime.utc(2026, 10, 1).subtract(Duration(days: i)).toIso8601String(),
          )),
      ];
      final contacts = _FakeContacts(many);
      await _pump(tester, _overrides(contacts));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
      await tester.pumpAndSettle();

      expect(contacts.calls.last.after, 'c-${AppConfig.contactsPageSize - 1}');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(find.text('Client ${(AppConfig.contactsPageSize + 4).toString().padLeft(2, '0')}'), findsOneWidget);
    });

    testWidgets('a booking change reloads the list without losing loaded pages', (tester) async {
      final changes = StreamController<int>();
      addTearDown(changes.close);
      final many = [
        for (var i = 0; i < AppConfig.contactsPageSize + 5; i++)
          ProviderContact.fromJson(_row(clientId: 'c-$i', name: 'Client $i')),
      ];
      final contacts = _FakeContacts(many);
      await _pump(tester, _overrides(contacts, changes: changes.stream));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -6000));
      await tester.pumpAndSettle();
      contacts.calls.clear();

      changes.add(1);
      await tester.pumpAndSettle();

      expect(contacts.calls.single.after, isNull);
      expect(contacts.calls.single.limit, AppConfig.contactsPageSize + 5);
    });
  });

  group('Client sheet', () {
    testWidgets("opens with the client's details, totals and every booking", (tester) async {
      final bookings = _FakeBookings();
      await _pump(tester, _overrides(_FakeContacts([_michelle, _sam]), bookings: bookings));

      await tester.tap(find.text('Michelle Zhang'));
      await tester.pumpAndSettle();

      expect(find.byType(ClientContactSheet), findsOneWidget);
      expect(find.text('Client since March 2026'), findsOneWidget);
      expect(find.text('0412 345 678'), findsOneWidget);
      expect(find.bySemanticsLabel('Visits: 2'), findsOneWidget);
      expect(find.bySemanticsLabel('Bookings: 3'), findsOneWidget);
      expect(find.bySemanticsLabel(r'Paid: $230'), findsOneWidget);
      expect(find.text('Booking history'), findsOneWidget);
      expect(bookings.requests.single, (providerId: 'prov-1', clientId: 'client-1', after: null));

      // Pull the sheet up to full height to see the whole history.
      await tester.drag(find.text('Client since March 2026'), const Offset(0, -400));
      await tester.pumpAndSettle();
      final sheet = find.byType(ClientContactSheet);
      expect(find.descendant(of: sheet, matching: find.byType(ClientBookingTile)), findsNWidgets(3));
      expect(find.descendant(of: sheet, matching: find.text('Confirmed')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('Completed')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('Paid (Cash)')), findsOneWidget);
      expect(find.descendant(of: sheet, matching: find.text('Cancelled')), findsOneWidget);
      // An appointment in another year says which.
      final other = find.textContaining('${2027} · ');
      expect(other, _thisYear() == 2027 ? findsNothing : findsOneWidget);
    });

    testWidgets('the number can be copied', (tester) async {
      final copied = _watchClipboard(tester);
      await _pump(tester, _overrides(_FakeContacts([_michelle])));

      await tester.tap(find.text('Michelle Zhang'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Copy 0412 345 678'));
      await tester.pumpAndSettle();

      expect(copied, ['0412 345 678']);
      expect(find.text('Phone number copied'), findsOneWidget);
    });

    testWidgets('a private email stays hidden: only call and message are offered', (tester) async {
      await _pump(tester, _overrides(_FakeContacts([_michelle])));

      await tester.tap(find.text('Michelle Zhang'));
      await tester.pumpAndSettle();

      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Email'), findsNothing);
      expect(find.byIcon(Icons.mail_outline_rounded), findsNothing);
    });

    testWidgets('a public email is shown and can be emailed or copied', (tester) async {
      final copied = _watchClipboard(tester);
      final launcher = _FakeLauncher();
      final withEmail = ProviderContact.fromJson(_row(email: 'michelle@example.com'));
      await _pump(tester, _overrides(_FakeContacts([withEmail]), launcher: launcher));

      await tester.tap(find.text('Michelle Zhang'));
      await tester.pumpAndSettle();

      expect(find.text('michelle@example.com'), findsOneWidget);
      expect(find.text('Email · shared on their profile'), findsOneWidget);

      await tester.tap(find.text('Email'));
      await tester.pumpAndSettle();
      expect(launcher.launched, ['email:michelle@example.com']);

      await tester.tap(find.byTooltip('Copy michelle@example.com'));
      await tester.pumpAndSettle();
      expect(copied, ['michelle@example.com']);
      expect(find.text('Email address copied'), findsOneWidget);
    });

    testWidgets('call and message open the phone and messages apps', (tester) async {
      final launcher = _FakeLauncher();
      await _pump(tester, _overrides(_FakeContacts([_michelle]), launcher: launcher));

      await tester.tap(find.text('Michelle Zhang'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Call'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();

      expect(launcher.launched, ['call:0412 345 678', 'message:0412 345 678']);
    });

    testWidgets('without a phone app the number is copied instead', (tester) async {
      final copied = _watchClipboard(tester);
      await _pump(tester, _overrides(_FakeContacts([_michelle]), launcher: _FakeLauncher(opens: false)));

      await tester.tap(find.text('Michelle Zhang'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Call'));
      await tester.pumpAndSettle();

      expect(copied, ['0412 345 678']);
      expect(find.text("Couldn't open a phone app, so the number was copied"), findsOneWidget);
    });

    testWidgets('a booking opens over the sheet, and going back returns to it', (tester) async {
      await _pump(tester, _overrides(_FakeContacts([_michelle])));

      await tester.tap(find.text('Michelle Zhang'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Completed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      expect(find.text('Detail b-done'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Detail b-done'), findsNothing);
      expect(find.byType(ClientContactSheet), findsOneWidget);
      expect(find.text('Booking history'), findsOneWidget);
    });

    testWidgets('a failed bookings load is shown in the sheet and can be retried', (tester) async {
      var attempts = 0;
      await _pump(tester, [
        ..._overrides(_FakeContacts([_michelle])),
        clientBookingsProvider('client-1').overrideWith(() => _FlakyClientBookings(() => ++attempts)),
      ]);

      await tester.tap(find.text('Michelle Zhang'));
      await tester.pumpAndSettle();
      expect(find.text("Bookings didn't load"), findsOneWidget);

      await tester.ensureVisible(find.text('Try again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text("Bookings didn't load"), findsNothing);
      expect(attempts, 2);
    });
  });
}

/// Fails its first load, then has no bookings.
class _FlakyClientBookings extends ClientBookingsController {
  _FlakyClientBookings(this.onBuild) : super('client-1');

  final int Function() onBuild;

  @override
  Future<BookingPage> build() async {
    if (onBuild() == 1) throw const PostgrestException(message: 'boom', code: '500');
    return const BookingPage(items: [], hasMore: false);
  }
}
