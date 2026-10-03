import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/discovery_feed/models/post_repository.dart';
import 'package:myglo/src/features/discovery_feed/views/upload_post_screen.dart';
import 'package:myglo/src/features/providers/provider_profiles/models/service_model.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockPostRepository extends Mock implements PostRepository {}

final _service = ServiceModel(
  id: 'svc-1',
  providerId: 'prov-1',
  name: 'Balayage',
  description: '',
  price: 240,
  durationMinutes: 150,
  createdAt: DateTime.utc(2026, 9, 1),
);

AppUserProfile _user(UserRole role) => AppUserProfile(
  rawUser: User(
    id: 'prov-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
  ),
  role: role,
  profile: ProfileModel(id: 'prov-1', role: role, providerName: 'Glow Studio'),
);

// The caption field has its own Scrollable; scroll the page itself.
final _page = find.byType(Scrollable).first;

Future<void> _pump(WidgetTester tester, {required UserRole role, required List<ServiceModel> services}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repository = _MockPostRepository();
  when(() => repository.getProviderServices(any())).thenAnswer((_) async => services);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileProvider.overrideWith((ref) async => _user(role)),
        postRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const UploadPostScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts media-first and cannot publish without photos', (tester) async {
    await _pump(tester, role: UserRole.provider, services: [_service]);

    // The gallery opens straight away; backing out of it leaves the canvas.
    expect(find.text('Choose photos'), findsOneWidget);

    final publish = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Publish post'));
    expect(publish.onPressed, isNull);
  });

  testWidgets('providers can link one of their services', (tester) async {
    await _pump(tester, role: UserRole.provider, services: [_service]);

    await tester.scrollUntilVisible(find.text('Choose the service shown'), 200, scrollable: _page);
    await tester.tap(find.text('Choose the service shown'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balayage'));
    await tester.pumpAndSettle();

    expect(find.text('Balayage'), findsOneWidget);
    expect(find.text(r'$240 · 2 hr 30 min'), findsOneWidget);
    expect(find.byTooltip('Unlink service'), findsOneWidget);
  });

  testWidgets('providers without services are told to add one first', (tester) async {
    await _pump(tester, role: UserRole.provider, services: const []);

    await tester.scrollUntilVisible(find.text('Add a service first to link it to your posts.'), 200, scrollable: _page);
    expect(find.text('Add a service first to link it to your posts.'), findsOneWidget);
  });

  testWidgets('clients tag a provider before linking a service', (tester) async {
    await _pump(tester, role: UserRole.customer, services: [_service]);

    await tester.scrollUntilVisible(find.text('Search for the provider who did this'), 200, scrollable: _page);
    expect(find.text('Search for the provider who did this'), findsOneWidget);
    expect(find.text('Link a service'), findsNothing);
  });
}
