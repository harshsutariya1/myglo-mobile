import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myglo/src/core/routing/app_router.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/core/widgets/skeleton/skeletons.dart';
import 'package:myglo/src/features/customers/booking/views/select_services_screen.dart';
import 'package:myglo/src/features/customers/booking/views/widgets/compact_service_list.dart';
import 'package:myglo/src/features/customers/booking/views/widgets/selected_services_sheet.dart';
import 'package:myglo/src/features/customers/provider_profile/controllers/public_provider_profile_controller.dart';
import 'package:myglo/src/features/customers/provider_profile/views/public_provider_profile_screen.dart';
import 'package:myglo/src/features/customers/provider_profile/views/widgets/provider_services_tab.dart';
import 'package:myglo/src/features/discovery_feed/controllers/service_posts_controller.dart';
import 'package:myglo/src/features/discovery_feed/controllers/user_posts_controller.dart';
import 'package:myglo/src/features/discovery_feed/models/post_model.dart';
import 'package:myglo/src/features/providers/provider_profiles/controllers/provider_services_controller.dart';
import 'package:myglo/src/features/providers/provider_profiles/models/service_model.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';

const _id = 'prov-1';

const _profile = ProfileModel(id: _id, role: UserRole.provider, providerName: 'Glow Studio');

ServiceModel _service(String name, {String? category, double price = 45, int minutes = 60, String? description}) =>
    ServiceModel(
      id: name,
      providerId: _id,
      name: name,
      description: description ?? '$name description',
      price: price,
      durationMinutes: minutes,
      createdAt: DateTime.utc(2026, 9, 1),
      category: category,
    );

final _catalogue = [
  _service('Lash lift', category: 'Lashes', price: 85, minutes: 90, description: 'Lift.\n• Lift\n• Tint'),
  _service('Lash tint', category: 'Lashes', price: 30, minutes: 20),
  _service('Brow wax', category: 'Brows', price: 25, minutes: 15),
  _service('Consultation'),
];

PostModel _post(String id, {required String serviceId}) => PostModel(
  id: id,
  authorId: _id,
  mediaUrls: const ['https://example.com/work.jpg'],
  caption: 'Fresh $id',
  serviceId: serviceId,
  tagStatus: 'approved',
  likesCount: 0,
  commentsCount: 0,
  createdAt: DateTime.utc(2026, 9, 2),
  updatedAt: DateTime.utc(2026, 9, 2),
);

List<Override> _overrides(
  FutureOr<List<ServiceModel>> Function() services, {
  Map<String, List<PostModel>> servicePosts = const {},
}) => [
  userProfileProvider.overrideWith((ref) async => null),
  publicProviderProfileProvider(_id).overrideWith((ref) => _profile),
  providerServicesProvider(_id).overrideWith((ref) => services()),
  userPostsProvider(_id).overrideWith((ref) => const []),
  servicePostsProvider.overrideWith((ref, serviceId) => servicePosts[serviceId] ?? const []),
];

Future<void> _pump(
  WidgetTester tester, {
  required FutureOr<List<ServiceModel>> Function() services,
  Map<String, List<PostModel>> servicePosts = const {},
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: _overrides(services, servicePosts: servicePosts),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SelectServicesScreen(providerId: _id),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('shows a skeleton while services load', (tester) async {
    final never = Completer<Never>();
    await _pump(tester, services: () => never.future);

    expect(find.byType(ServiceRowSkeleton), findsWidgets);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('shows an error with retry when services fail', (tester) async {
    await _pump(tester, services: () => throw const SocketException('offline'));

    expect(find.text("Services didn't load"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('shows an empty state for a provider with no services', (tester) async {
    await _pump(tester, services: () => const []);

    expect(find.text('No services to book yet'), findsOneWidget);
  });

  testWidgets('opens on All, listing every service compactly by category', (tester) async {
    await _pump(tester, services: () => _catalogue);

    expect(find.text('Glow Studio'), findsOneWidget);
    for (final category in [allServicesLabel, 'Lashes', 'Brows', uncategorisedServicesLabel]) {
      expect(find.text(category), findsOneWidget);
    }
    for (final name in ['Lash lift', 'Lash tint', 'Brow wax', 'Consultation']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('LASHES'), findsOneWidget);
    // Compact rows have no thumbnail or details link.
    expect(find.text('View details'), findsNothing);
    // ...so a hint explains how to open details instead.
    expect(find.text(compactListHintText), findsOneWidget);
  });

  testWidgets('the category menu jumps to any category', (tester) async {
    await _pump(tester, services: () => _catalogue);

    await tester.tap(find.byTooltip('All categories'));
    await tester.pumpAndSettle();
    // Each category appears in both the menu and the pill bar.
    expect(find.text('Brows'), findsNWidgets(2));

    await tester.tap(find.text(uncategorisedServicesLabel).last);
    await tester.pumpAndSettle();
    expect(find.text('Consultation'), findsOneWidget);
    expect(find.text('Lash lift'), findsNothing);
  });

  testWidgets('a category pill shows only that category', (tester) async {
    await _pump(tester, services: () => _catalogue);

    await tester.tap(find.text('Lashes'));
    await tester.pumpAndSettle();
    expect(find.text('Lash lift'), findsOneWidget);
    expect(find.text('Lash tint'), findsOneWidget);
    expect(find.text('Brow wax'), findsNothing);

    await tester.tap(find.text('Brows'));
    await tester.pumpAndSettle();
    expect(find.text('Brow wax'), findsOneWidget);
    expect(find.text('Lash lift'), findsNothing);

    // Swiping moves to the next category and syncs the pills.
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Consultation'), findsOneWidget);
  });

  testWidgets('selecting services shows the running total and Continue', (tester) async {
    await _pump(tester, services: () => _catalogue);
    expect(find.text('Continue'), findsNothing);

    await tester.tap(find.text('Lash lift'));
    await tester.pumpAndSettle();
    expect(find.text(r'$85'), findsNWidgets(2)); // Tile and footer.
    expect(find.text('1 service · 1 hr 30 min'), findsOneWidget);

    // Selections carry across categories and are counted on their pill.
    await tester.tap(find.text('Brows'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Brow wax'));
    await tester.pumpAndSettle();
    expect(find.text(r'$110'), findsOneWidget);
    expect(find.text('2 services · 1 hr 45 min'), findsOneWidget);
    expect(find.bySemanticsLabel('Lashes, 1 selected'), findsOneWidget);
    expect(find.bySemanticsLabel('All, 2 selected'), findsOneWidget);

    // Tapping again unselects.
    await tester.tap(find.text('Brow wax'));
    await tester.pumpAndSettle();
    expect(find.text('1 service · 1 hr 30 min'), findsOneWidget);
  });

  testWidgets('Continue opens the date & time step', (tester) async {
    await _pumpSelectionWithRouter(tester);
    await tester.tap(find.text('Lash tint'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text(_timeStepStub), findsOneWidget);
  });

  testWidgets('the total opens a sheet of selected services that can be removed', (tester) async {
    await _pump(tester, services: () => _catalogue);
    await tester.tap(find.text('Lash lift'));
    await tester.tap(find.text('Lash tint'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(r'$115'));
    await tester.pumpAndSettle();

    final sheet = find.byType(SelectedServicesSheet);
    expect(find.descendant(of: sheet, matching: find.text('Your selection')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Includes Lift, Tint')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Total · 2 services')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text(r'$115')), findsOneWidget);

    await tester.tap(find.byTooltip('Remove Lash lift'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: sheet, matching: find.text('Lash lift')), findsNothing);
    expect(find.descendant(of: sheet, matching: find.text(r'$30')), findsNWidgets(2));

    // Removing the last service closes the sheet and hides the footer.
    await tester.tap(find.byTooltip('Remove Lash tint'));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('Continue in the sheet closes it and opens the date & time step', (tester) async {
    await _pumpSelectionWithRouter(tester);
    await tester.tap(find.text('Lash tint'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(r'$30').last);
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(SelectedServicesSheet), matching: find.text('Continue')));
    await tester.pumpAndSettle();
    expect(find.byType(SelectedServicesSheet), findsNothing);
    expect(find.text(_timeStepStub), findsOneWidget);
  });

  testWidgets('Book Now on the provider profile opens service selection', (tester) async {
    await _pumpProfileWithRouter(tester);

    await tester.tap(find.text('Book Now'));
    await tester.pumpAndSettle();

    expect(find.byType(SelectServicesScreen), findsOneWidget);
    expect(find.text('Select services'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets("a service's + opens selection with it selected, on its category", (tester) async {
    await _pumpProfileWithRouter(tester);

    await tester.scrollUntilVisible(find.byTooltip('Book Brow wax'), 200);
    await tester.tap(find.byTooltip('Book Brow wax'));
    await tester.pumpAndSettle();

    expect(find.byType(SelectServicesScreen), findsOneWidget);
    expect(find.bySemanticsLabel('Brows, 1 selected'), findsOneWidget);
    expect(find.text('Lash lift'), findsNothing);
    expect(find.text('1 service · 15 min'), findsOneWidget);
  });

  testWidgets('service details show recent work only when tagged posts exist', (tester) async {
    await _pump(
      tester,
      services: () => _catalogue,
      servicePosts: {'Lash lift': [_post('post-1', serviceId: 'Lash lift'), _post('post-2', serviceId: 'Lash lift')]},
    );

    // Long-pressing a compact row opens the full details.
    await tester.longPress(find.text('Lash lift'));
    await _pumpFrames(tester);
    expect(find.text("What's included"), findsOneWidget);
    expect(find.text('Add to selection'), findsOneWidget);
    expect(find.text('Cancellation policy'), findsNothing);
    expect(find.textContaining('GST'), findsNothing);
    await tester.drag(find.text("What's included"), const Offset(0, -400));
    await _pumpFrames(tester);
    expect(find.textContaining('Recent work'), findsOneWidget);
    expect(find.bySemanticsLabel('Post: Fresh post-1'), findsOneWidget);

    // Adding from the sheet selects the service and closes the sheet.
    await tester.tap(find.text('Add to selection'));
    await _pumpFrames(tester);
    expect(find.text('1 service · 1 hr 30 min'), findsOneWidget);

    await tester.longPress(find.text('Brow wax'));
    await _pumpFrames(tester);
    expect(find.textContaining('Recent work'), findsNothing);
  });
}

/// Lets sheet and page transitions finish while image placeholders keep
/// shimmering (test images never load, so pumpAndSettle would time out).
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const _timeStepStub = 'Date & time step';

/// Service selection inside the real route tree, with the next step stubbed.
Future<void> _pumpSelectionWithRouter(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/provider/$_id/book',
    routes: [
      GoRoute(
        path: AppRoute.publicProviderProfile.path,
        name: AppRoute.publicProviderProfile.name,
        builder: (_, state) => const SizedBox.shrink(),
        routes: [
          GoRoute(
            path: AppRoute.selectServices.path,
            name: AppRoute.selectServices.name,
            builder: (_, state) => SelectServicesScreen(providerId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: AppRoute.selectDateTime.path,
                name: AppRoute.selectDateTime.name,
                builder: (_, _) => const Scaffold(body: Text(_timeStepStub)),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: _overrides(() => _catalogue),
      child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpProfileWithRouter(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/provider/$_id',
    routes: [
      GoRoute(
        path: AppRoute.publicProviderProfile.path,
        name: AppRoute.publicProviderProfile.name,
        builder: (_, state) => PublicProviderProfileScreen(providerId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: AppRoute.selectServices.path,
            name: AppRoute.selectServices.name,
            builder: (_, state) => SelectServicesScreen(
              providerId: state.pathParameters['id']!,
              initialServiceId: state.uri.queryParameters[selectServicesInitialServiceParam],
            ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: _overrides(() => _catalogue),
      child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}
