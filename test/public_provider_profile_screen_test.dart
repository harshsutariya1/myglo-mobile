import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/core/widgets/skeleton/skeletons.dart';
import 'package:myglo/src/features/customers/provider_profile/controllers/public_provider_profile_controller.dart';
import 'package:myglo/src/features/customers/provider_profile/views/public_provider_profile_screen.dart';
import 'package:myglo/src/features/customers/provider_profile/views/widgets/provider_profile_header.dart';
import 'package:myglo/src/features/customers/provider_profile/views/widgets/provider_services_tab.dart';
import 'package:myglo/src/features/discovery_feed/controllers/user_posts_controller.dart';
import 'package:myglo/src/features/discovery_feed/models/post_model.dart';
import 'package:myglo/src/features/providers/provider_profiles/controllers/provider_services_controller.dart';
import 'package:myglo/src/features/providers/provider_profiles/models/service_model.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';

const _id = 'prov-1';

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
}) async {
  await tester.pumpWidget(
    ProviderScope(
      // Failures must surface immediately, not after automatic retries.
      retry: (_, _) => null,
      overrides: [
        userProfileProvider.overrideWith((ref) async => null),
        publicProviderProfileProvider(_id).overrideWith((ref) => profile()),
        providerServicesProvider(_id).overrideWith((ref) => services()),
        userPostsProvider(_id).overrideWith((ref) => posts()),
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
    expect(find.text(r'$85  •  1 hr 30 min'), findsOneWidget);
    await tester.scrollUntilVisible(find.text(uncategorisedServicesLabel), 200);
    expect(find.text(uncategorisedServicesLabel), findsOneWidget);
    await tester.scrollUntilVisible(find.text(r'$45  •  1 hr'), 200);
    expect(find.text(r'$45  •  1 hr'), findsOneWidget);
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

    await tester.tap(find.text('Posts'));
    await tester.pump();
    expect(find.text('No posts yet'), findsOneWidget);

    await tester.tap(find.text('About'));
    await tester.pump();
    expect(find.text('Lashes and brows on the Gold Coast.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('No reviews yet'), 200);
    expect(find.text('No reviews yet'), findsOneWidget);
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
}
