import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/providers/provider_profiles/models/service_model.dart';
import 'package:myglo/src/features/providers/provider_profiles/models/service_repository.dart';
import 'package:myglo/src/features/providers/provider_profiles/views/screens/add_service_screen.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockServiceRepository extends Mock implements ServiceRepository {}

final _service = ServiceModel(
  id: 'svc-1',
  providerId: 'prov-1',
  name: 'Hair Spa',
  description: 'Relaxing treatment.\n• Pre-wash',
  price: 85,
  durationMinutes: 45,
  createdAt: DateTime.utc(2026, 9, 1),
  category: 'Hair',
);

final _owner = AppUserProfile(
  rawUser: User(
    id: 'prov-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
  ),
  role: UserRole.provider,
  profile: const ProfileModel(id: 'prov-1', role: UserRole.provider),
);

final _page = find.byType(Scrollable).first;

Future<_MockServiceRepository> _pump(WidgetTester tester, Widget screen) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repository = _MockServiceRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileProvider.overrideWith((ref) async => _owner),
        serviceRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('new service validates required fields', (tester) async {
    await _pump(tester, const AddServiceScreen());

    await tester.tap(find.text('Save & publish service'));
    await tester.pumpAndSettle();

    expect(find.text('Give your service a title'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Choose how long the service takes'), 200, scrollable: _page);
    expect(find.text('Enter a price'), findsOneWidget);
    expect(find.text('Choose how long the service takes'), findsOneWidget);
  });

  testWidgets('edit prefills the form', (tester) async {
    await _pump(tester, AddServiceScreen.edit(_service));

    expect(find.text('Edit service'), findsOneWidget);
    expect(find.text('Hair Spa'), findsOneWidget);
    expect(find.text('85'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('duplicate starts a new copy of the service', (tester) async {
    await _pump(tester, AddServiceScreen.duplicate(_service));

    expect(find.text('Duplicate service'), findsOneWidget);
    expect(find.text('Hair Spa (copy)'), findsOneWidget);
    expect(find.text('Save & publish service'), findsOneWidget);
  });

  testWidgets('the bullet shortcut adds an included item', (tester) async {
    await _pump(tester, AddServiceScreen.edit(_service));

    await tester.scrollUntilVisible(find.text('Add included item'), 200, scrollable: _page);
    await tester.tap(find.text('Add included item'));
    await tester.pump();

    final field = tester.widget<EditableText>(
      find.descendant(of: find.widgetWithText(TextFormField, 'Description'), matching: find.byType(EditableText)),
    );
    expect(field.controller.text, 'Relaxing treatment.\n• Pre-wash\n• ');
  });

  testWidgets('the bullet shortcut works on an empty description', (tester) async {
    await _pump(tester, const AddServiceScreen());

    await tester.scrollUntilVisible(find.text('Add included item'), 200, scrollable: _page);
    await tester.tap(find.text('Add included item'));
    await tester.pump();
    await tester.tap(find.text('Add included item'));
    await tester.pump();

    final field = tester.widget<EditableText>(
      find.descendant(of: find.widgetWithText(TextFormField, 'Description'), matching: find.byType(EditableText)),
    );
    expect(field.controller.text, '• ');
  });

  testWidgets('saving an edit updates the service and closes the form', (tester) async {
    final repository = await _pump(tester, AddServiceScreen.edit(_service));
    when(
      () => repository.updateService(
        id: any(named: 'id'),
        name: any(named: 'name'),
        description: any(named: 'description'),
        price: any(named: 'price'),
        durationMinutes: any(named: 'durationMinutes'),
        category: any(named: 'category'),
        imageUrl: any(named: 'imageUrl'),
      ),
    ).thenAnswer((_) async => _service);

    await tester.enterText(find.widgetWithText(TextFormField, 'Hair Spa'), 'Hair Spa Deluxe');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    verify(
      () => repository.updateService(
        id: 'svc-1',
        name: 'Hair Spa Deluxe',
        description: 'Relaxing treatment.\n• Pre-wash',
        price: 85,
        durationMinutes: 45,
        category: 'Hair',
        imageUrl: null,
      ),
    ).called(1);
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Service updated'), findsOneWidget);
  });

  testWidgets('leaving with unsaved changes asks first', (tester) async {
    await _pump(tester, AddServiceScreen.edit(_service));

    await tester.enterText(find.widgetWithText(TextFormField, 'Hair Spa'), 'Changed');
    await tester.pump(); // Rebuild so the back guard sees the edit.
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });
}
