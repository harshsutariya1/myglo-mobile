import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/maps/google/google_maps_links.dart';
import 'package:myglo/src/core/platform/system_bridge.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/core/widgets/skeleton/skeletons.dart';
import 'package:myglo/src/features/customers/booking/views/widgets/location_preview.dart';
import 'package:myglo/src/features/customers/provider_profile/controllers/public_provider_profile_controller.dart';
import 'package:myglo/src/features/customers/provider_profile/views/public_provider_profile_screen.dart';
import 'package:myglo/src/features/customers/provider_profile/views/widgets/provider_profile_header.dart';
import 'package:myglo/src/features/customers/provider_profile/views/widgets/provider_services_tab.dart';
import 'package:myglo/src/features/discovery_feed/controllers/service_posts_controller.dart';
import 'package:myglo/src/features/discovery_feed/controllers/user_posts_controller.dart';
import 'package:myglo/src/features/discovery_feed/models/post_model.dart';
import 'package:myglo/src/features/providers/provider_profiles/controllers/provider_services_controller.dart';
import 'package:myglo/src/features/providers/provider_profiles/models/service_model.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:myglo/src/features/shared/bookings/controllers/booking_controllers.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_settings.dart';
import 'package:myglo/src/features/shared/bookings/models/working_hours.dart';
import 'package:myglo/src/features/shared/reviews/controllers/reviews_controllers.dart';
import 'package:myglo/src/features/shared/reviews/models/review.dart';
import 'package:myglo/src/features/shared/reviews/models/review_summary.dart';

const _id = 'prov-1';

class _FakeSystem implements SystemBridge {
  final opened = <({Uri url, Uri? appUrl, String? appPackage})>[];

  @override
  Future<bool> mapsAvailable() async => false;

  @override
  Future<bool> notificationsEnabled() async => true;

  @override
  Future<bool> openNotificationSettings() async => true;

  @override
  Future<bool> share({required String text, required Uri url, String? subject, Rect? origin}) async => true;

  @override
  Future<bool> openUrl(Uri url, {Uri? appUrl, String? appPackage}) async {
    opened.add((url: url, appUrl: appUrl, appPackage: appPackage));
    return true;
  }
}

const _profile = ProfileModel(
  id: _id,
  role: UserRole.provider,
  providerName: 'Glow Studio',
  addressText: '1 Cavill Ave, Surfers Paradise QLD',
  bio: 'Lashes and brows on the Gold Coast.',
);

ServiceModel _service(String name, {String? category, double price = 45, int minutes = 60}) => ServiceModel(
  id: name,
  providerId: _id,
  name: name,
  description: '$name description',
  price: price,
  durationMinutes: minutes,
  createdAt: DateTime.utc(2026, 9, 1),
  category: category,
);

Future<void> _pump(
  WidgetTester tester, {
  required FutureOr<ProfileModel?> Function() profile,
  required FutureOr<List<ServiceModel>> Function() services,
  required FutureOr<List<PostModel>> Function() posts,
  WeeklySchedule? hours,
  ProviderBookingSettings settings = const ProviderBookingSettings(providerId: _id),
  ReviewSummary reviewSummary = ReviewSummary.empty,
  List<Review> reviews = const [],
  SystemBridge system = const MethodChannelSystemBridge(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      // Failures must surface immediately, not after automatic retries.
      retry: (_, _) => null,
      overrides: [
        userProfileProvider.overrideWith((ref) async => null),
        systemBridgeProvider.overrideWithValue(system),
        publicProviderProfileProvider(_id).overrideWith((ref) => profile()),
        providerServicesProvider(_id).overrideWith((ref) => services()),
        userPostsProvider(_id).overrideWith((ref) => posts()),
        servicePostsProvider.overrideWith((ref, serviceId) => const []),
        bookingSettingsProvider(_id).overrideWith((ref) => Stream.value(settings)),
        workingHoursProvider(_id).overrideWith((ref) async => hours ?? WeeklySchedule(const [])),
        providerReviewSummaryProvider(_id).overrideWith((ref) async => reviewSummary),
        serviceReviewSummaryProvider.overrideWith((ref, serviceId) async => ReviewSummary.empty),
        reviewsPreviewProvider.overrideWith((ref, query) async => reviews),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const PublicProviderProfileScreen(providerId: _id),
      ),
    ),
  );
}

void main() {
  testWidgets('shows skeletons for every section while loading', (tester) async {
    final never = Completer<Never>();
    await _pump(
      tester,
      profile: () => never.future,
      services: () => never.future,
      posts: () => never.future,
    );
    await tester.pump();

    expect(find.byType(ProviderProfileHeaderSkeleton), findsOneWidget);
    expect(find.byType(ServiceRowSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a failed services fetch does not block the header', (tester) async {
    await _pump(
      tester,
      profile: () => _profile,
      services: () => throw const SocketException('offline'),
      posts: () => const [],
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Glow Studio'), findsOneWidget);
    expect(find.text('Book Now'), findsOneWidget);
    expect(find.text("Services didn't load"), findsOneWidget);
    expect(find.textContaining('offline'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a failed profile fetch still shows services', (tester) async {
    await _pump(
      tester,
      profile: () => throw Exception('boom'),
      services: () => [_service('Lash lift')],
      posts: () => const [],
    );
    await tester.pump();
    await tester.pump();

    expect(find.text("Profile didn't load"), findsOneWidget);
    expect(find.text('Lash lift'), findsOneWidget);
  });

  testWidgets('groups services by category with AUD price and duration', (tester) async {
    // Tiles show the category, name, duration and price on separate lines.
    await _pump(
      tester,
      profile: () => _profile,
      services: () => [
        _service('Lash lift', category: 'Lashes', price: 85, minutes: 90),
        _service('Brow tint'),
      ],
      posts: () => const [],
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Lashes'), findsOneWidget);
    expect(find.text('LASHES'), findsOneWidget);
    expect(find.text(r'$85'), findsOneWidget);
    expect(find.text('1 hr 30 min'), findsOneWidget);
    await tester.scrollUntilVisible(find.text(uncategorisedServicesLabel), 200);
    expect(find.text(uncategorisedServicesLabel), findsOneWidget);
    await tester.scrollUntilVisible(find.text(r'$45'), 200);
    expect(find.text(r'$45'), findsOneWidget);
    expect(find.text('1 hr'), findsOneWidget);
  });

  testWidgets('tapping a service opens its details with a booking action', (tester) async {
    await _pump(
      tester,
      profile: () => _profile,
      services: () => [
        _service('Lash lift', category: 'Lashes', price: 85, minutes: 90).copyWith(
          description: 'Lift and tint.\n• Lash lift\n• Tint',
        ),
      ],
      posts: () => const [],
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Lash lift'));
    await tester.pumpAndSettle();

    expect(find.text("What's included"), findsOneWidget);
    expect(find.text('Tint'), findsOneWidget);
    expect(find.text('Book now'), findsOneWidget);
    expect(find.text('Cancellation policy'), findsNothing);
    expect(find.textContaining('GST'), findsNothing);

    // The sheet opens part-way; dragging expands it to reveal the rest.
    await tester.drag(find.text("What's included"), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Lift and tint.'), findsOneWidget);
  });

  testWidgets('shows empty states for a provider with no services or posts', (tester) async {
    await _pump(
      tester,
      profile: () => _profile,
      services: () => const [],
      posts: () => const [],
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No services listed yet'), findsOneWidget);

    await tester.tap(find.text('Portfolio'));
    await tester.pump();
    expect(find.text('No portfolio yet'), findsOneWidget);

    await tester.tap(find.text('About'));
    await tester.pump();
    expect(find.text('Lashes and brows on the Gold Coast.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('No reviews yet'), 200);
    expect(find.text('No reviews yet'), findsOneWidget);
    expect(find.text('Hours not listed yet'), findsOneWidget);
  });

  testWidgets('lists the weekly opening hours in the provider time zone', (tester) async {
    await _pump(
      tester,
      profile: () => _profile,
      services: () => const [],
      posts: () => const [],
      hours: WeeklySchedule([
        for (var day = 1; day <= 5; day++)
          WorkingHoursRange(weekday: day, opensMinutes: 9 * 60, closesMinutes: 17 * 60),
        const WorkingHoursRange(weekday: 6, opensMinutes: 9 * 60, closesMinutes: 12 * 60),
        const WorkingHoursRange(weekday: 6, opensMinutes: 13 * 60, closesMinutes: 15 * 60),
      ]),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('About'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Times in Gold Coast time (AEST)'), 200);

    expect(find.text('Hours not listed yet'), findsNothing);
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('9:00 am – 5:00 pm'), findsNWidgets(5));
    expect(find.text('9:00 am – 12:00 pm\n1:00 pm – 3:00 pm'), findsOneWidget);
    expect(find.text('Closed'), findsOneWidget);
  });

  testWidgets('shows the provider cancellation policy', (tester) async {
    await _pump(
      tester,
      profile: () => _profile,
      services: () => const [],
      posts: () => const [],
      settings: const ProviderBookingSettings(providerId: _id, cancellationWindowHours: 48, cancellationFeePercent: 50),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('About'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Free cancellation up to 2 days before'), 200);

    expect(find.text('No policy published'), findsNothing);
    // The 50% fee only applies to bookings paid in the app, which aren't live.
    expect(find.text('No fee on cash bookings; later cancellations are recorded as late.'), findsOneWidget);
    expect(find.textContaining('50%'), findsNothing);
  });

  testWidgets('shows a not-found state for an unknown or non-provider id', (tester) async {
    await _pump(
      tester,
      profile: () => null,
      services: () => const [],
      posts: () => const [],
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Provider not found'), findsOneWidget);
    expect(find.text('Go back'), findsOneWidget);
  });

  testWidgets('the portfolio is a three-column photo grid with no captions or dates', (tester) async {
    final posts = [
      for (var i = 0; i < 4; i++)
        PostModel(
          id: 'post-$i',
          authorId: _id,
          mediaUrls: const [],
          caption: 'Look number $i',
          tagStatus: 'approved',
          likesCount: 0,
          commentsCount: 0,
          createdAt: DateTime.utc(2026, 9, 1 + i),
          updatedAt: DateTime.utc(2026, 9, 1 + i),
        ),
    ];
    await _pump(tester, profile: () => _profile, services: () => const [], posts: () => posts);
    await tester.pump();
    await tester.pump();

    expect(find.text('Posts'), findsNothing);
    await tester.tap(find.text('Portfolio'));
    await tester.pump();

    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    expect((grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount).crossAxisCount, 3);
    expect(find.bySemanticsLabel('Portfolio photo: Look number 0'), findsOneWidget);
    // No caption or date text under the tiles.
    expect(find.text('Look number 0'), findsNothing);
    expect(find.textContaining('ago'), findsNothing);
  });

  testWidgets('shows the rating in the header and the newest reviews in About', (tester) async {
    final reviews = [
      Review(
        id: 'r-1',
        bookingId: 'b-1',
        providerId: _id,
        clientId: 'c-1',
        reviewerName: 'Mia T.',
        rating: 5,
        body: 'Best lash lift on the coast.',
        serviceNames: const ['Lash lift'],
        reply: 'Thank you, Mia!',
        repliedAt: DateTime.utc(2026, 10, 2),
        createdAt: DateTime.utc(2026, 10, 1),
      ),
      Review(
        id: 'r-2',
        bookingId: 'b-2',
        providerId: _id,
        clientId: 'c-2',
        reviewerName: 'Ava K.',
        rating: 4,
        createdAt: DateTime.utc(2026, 9, 20),
      ),
    ];
    await _pump(
      tester,
      profile: () => _profile,
      services: () => const [],
      posts: () => const [],
      reviewSummary: const ReviewSummary(count: 2, average: 4.5, starCounts: [0, 0, 0, 1, 1]),
      reviews: reviews,
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('4.5', findRichText: true), findsWidgets);
    expect(find.textContaining('2 reviews', findRichText: true), findsOneWidget);
    expect(find.text('New · No reviews yet'), findsNothing);

    await tester.tap(find.text('About'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Ava K.'), 200);
    expect(find.text('Mia T.'), findsOneWidget);
    expect(find.text('Best lash lift on the coast.'), findsOneWidget);
    expect(find.textContaining('Response from Glow Studio'), findsOneWidget);
    expect(find.text('Thank you, Mia!'), findsOneWidget);
    // Both reviews are already shown, so there's nothing more to see.
    expect(find.textContaining('See all'), findsNothing);
  });

  group('location opens in Google Maps', () {
    const address = '1 Cavill Ave, Surfers Paradise QLD';
    const goldCoast = LocationCoordinates(type: 'Point', coordinates: [153.4296, -28.0015]);
    // The header shows the address too; only the About card opens Maps.
    final addressCard = find.widgetWithText(InkWell, address);

    Future<_FakeSystem> openAbout(WidgetTester tester, ProfileModel profile, {ProviderBookingSettings? settings}) async {
      final system = _FakeSystem();
      await _pump(
        tester,
        profile: () => profile,
        services: () => const [],
        posts: () => const [],
        system: system,
        settings: settings ?? const ProviderBookingSettings(providerId: _id),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('About'));
      await tester.pump();
      return system;
    }

    testWidgets('tapping the map or the address pins the exact location', (tester) async {
      final system = await openAbout(tester, _profile.copyWith(coordinates: goldCoast));

      await tester.scrollUntilVisible(addressCard, 200);
      expect(find.text('Open in Maps'), findsOneWidget);
      for (final target in [find.byType(LocationPreview), addressCard]) {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pump();
      }

      expect(system.opened, hasLength(2));
      for (final call in system.opened) {
        expect(call.url, Uri.parse('https://www.google.com/maps/search/?api=1&query=-28.001500%2C153.429600'));
        expect(call.appUrl, Uri.parse('comgooglemaps://?q=-28.001500%2C153.429600'));
        expect(call.appPackage, GoogleMapsLinks.androidPackage);
      }
    });

    testWidgets('without coordinates the address is searched instead', (tester) async {
      final system = await openAbout(tester, _profile);

      await tester.scrollUntilVisible(addressCard, 200);
      expect(find.text('Open in Maps'), findsNothing);
      await tester.ensureVisible(addressCard);
      await tester.pumpAndSettle();
      await tester.tap(addressCard);
      await tester.pump();

      expect(system.opened.single.url.queryParameters['query'], address);
    });

    testWidgets('nothing opens without an address', (tester) async {
      final system = await openAbout(tester, _profile.copyWith(addressText: null));

      await tester.scrollUntilVisible(find.text('Address not provided'), 200);
      expect(find.widgetWithText(InkWell, 'Address not provided'), findsNothing);
      await tester.tap(find.text('Address not provided'));
      await tester.pump();

      expect(system.opened, isEmpty);
    });

    testWidgets('a mobile-only provider shows no map or address to open', (tester) async {
      final system = await openAbout(
        tester,
        _profile.copyWith(coordinates: goldCoast),
        settings: const ProviderBookingSettings(providerId: _id, offersStudio: false, offersMobile: true),
      );

      await tester.scrollUntilVisible(find.text('Mobile service'), 200);
      expect(find.text('Open in Maps'), findsNothing);
      expect(addressCard, findsNothing);
      await tester.tap(find.text('Mobile service'));
      await tester.pump();

      expect(system.opened, isEmpty);
    });
  });
}
