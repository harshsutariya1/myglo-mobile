import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/customers/favourites/controllers/favourites_controller.dart';
import 'package:myglo/src/features/customers/favourites/models/favourites_repository.dart';
import 'package:myglo/src/features/customers/favourites/views/favourite_button.dart';
import 'package:myglo/src/features/customers/favourites/views/favourites_screen.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_repository.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockFavouritesRepository extends Mock implements FavouritesRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

const _clientId = 'client-1';

AppUserProfile _viewer(String id, UserRole role) => AppUserProfile(
  rawUser: User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
  ),
  role: role,
  profile: ProfileModel(id: id, role: role, firstName: 'Sam'),
);

ProfileModel _provider(String id, String name) =>
    ProfileModel(id: id, role: UserRole.provider, providerName: name, addressText: 'Southport QLD');

ProviderContainer _container(
  _MockFavouritesRepository favourites, {
  AppUserProfile? viewer,
  UserRepository? users,
}) {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      userProfileProvider.overrideWith((ref) async => viewer ?? _viewer(_clientId, UserRole.customer)),
      favouritesRepositoryProvider.overrideWithValue(favourites),
      if (users != null) userRepositoryProvider.overrideWithValue(users),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('FavouritesController', () {
    test('loads the client\'s saved providers', () async {
      final repository = _MockFavouritesRepository();
      when(() => repository.getFavouriteProviderIds(_clientId)).thenAnswer((_) async => ['p2', 'p1']);
      final container = _container(repository);
      container.listen(favouritesProvider, (_, _) {});

      final state = await container.read(favouritesProvider.future);
      expect(state.canFavourite, isTrue);
      expect(state.providerIds, ['p2', 'p1']);
    });

    test('providers can\'t favourite and nothing is fetched', () async {
      final repository = _MockFavouritesRepository();
      final container = _container(repository, viewer: _viewer('prov-9', UserRole.provider));
      container.listen(favouritesProvider, (_, _) {});

      final state = await container.read(favouritesProvider.future);
      expect(state.canFavourite, isFalse);
      expect(await container.read(favouritesProvider.notifier).toggle('p1'), isFalse);
      verifyNever(() => repository.getFavouriteProviderIds(any()));
      verifyNever(() => repository.addFavourite(clientId: any(named: 'clientId'), providerId: any(named: 'providerId')));
    });

    test('saving is optimistic and puts the newest first', () async {
      final repository = _MockFavouritesRepository();
      final saved = Completer<void>();
      when(() => repository.getFavouriteProviderIds(_clientId)).thenAnswer((_) async => ['p1']);
      when(() => repository.addFavourite(clientId: _clientId, providerId: 'p2')).thenAnswer((_) => saved.future);
      final container = _container(repository);
      container.listen(favouritesProvider, (_, _) {});
      await container.read(favouritesProvider.future);

      final result = container.read(favouritesProvider.notifier).toggle('p2');
      expect(container.read(favouritesProvider).value!.providerIds, ['p2', 'p1']);
      saved.complete();
      expect(await result, isTrue);
      expect(container.read(favouritesProvider).value!.providerIds, ['p2', 'p1']);
    });

    test('a failed removal puts the provider back where it was', () async {
      final repository = _MockFavouritesRepository();
      when(() => repository.getFavouriteProviderIds(_clientId)).thenAnswer((_) async => ['p3', 'p2', 'p1']);
      when(() => repository.removeFavourite(clientId: _clientId, providerId: 'p2'))
          .thenThrow(Exception('offline'));
      final container = _container(repository);
      container.listen(favouritesProvider, (_, _) {});
      await container.read(favouritesProvider.future);

      final ok = await container.read(favouritesProvider.notifier).setFavourite('p2', favourite: false);
      expect(ok, isFalse);
      expect(container.read(favouritesProvider).value!.providerIds, ['p3', 'p2', 'p1']);
    });

    test('a failed save is rolled back', () async {
      final repository = _MockFavouritesRepository();
      when(() => repository.getFavouriteProviderIds(_clientId)).thenAnswer((_) async => const []);
      when(() => repository.addFavourite(clientId: _clientId, providerId: 'p1')).thenThrow(Exception('offline'));
      final container = _container(repository);
      container.listen(favouritesProvider, (_, _) {});
      await container.read(favouritesProvider.future);

      expect(await container.read(favouritesProvider.notifier).toggle('p1'), isFalse);
      expect(container.read(favouritesProvider).value!.providerIds, isEmpty);
    });
  });

  group('FavouritesScreen', () {
    Future<(_MockFavouritesRepository, _MockUserRepository)> pump(WidgetTester tester, List<String> ids) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final favourites = _MockFavouritesRepository();
      final users = _MockUserRepository();
      when(() => favourites.getFavouriteProviderIds(_clientId)).thenAnswer((_) async => ids);
      when(() => favourites.removeFavourite(clientId: _clientId, providerId: any(named: 'providerId')))
          .thenAnswer((_) async {});
      when(() => favourites.addFavourite(clientId: _clientId, providerId: any(named: 'providerId')))
          .thenAnswer((_) async {});
      when(() => users.getPublicProfiles(any())).thenAnswer((_) async => {
            'p1': _provider('p1', 'Glow Studio'),
            'p2': _provider('p2', 'Lash Lab'),
          });

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            userProfileProvider.overrideWith((ref) async => _viewer(_clientId, UserRole.customer)),
            favouritesRepositoryProvider.overrideWithValue(favourites),
            userRepositoryProvider.overrideWithValue(users),
          ],
          child: MaterialApp(theme: AppTheme.lightTheme, home: const FavouritesScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return (favourites, users);
    }

    testWidgets('lists saved providers newest first', (tester) async {
      await pump(tester, ['p2', 'p1']);

      expect(find.text('2 saved providers'), findsOneWidget);
      final lash = tester.getTopLeft(find.text('Lash Lab'));
      final glow = tester.getTopLeft(find.text('Glow Studio'));
      expect(lash.dy, lessThan(glow.dy));
    });

    testWidgets('removing a provider can be undone', (tester) async {
      final (favourites, _) = await pump(tester, ['p2', 'p1']);

      await tester.tap(find.byTooltip('Remove from favourites').first);
      await tester.pumpAndSettle();
      expect(find.text('Lash Lab'), findsNothing);
      expect(find.text('Lash Lab removed from favourites'), findsOneWidget);
      verify(() => favourites.removeFavourite(clientId: _clientId, providerId: 'p2')).called(1);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      verify(() => favourites.addFavourite(clientId: _clientId, providerId: 'p2')).called(1);
      expect(find.text('Lash Lab'), findsOneWidget);
    });

    testWidgets('empty state points to Discover', (tester) async {
      await pump(tester, const []);

      expect(find.text('No favourites yet'), findsOneWidget);
      expect(find.text('Discover salons'), findsOneWidget);
    });
  });

  group('FavouriteButton', () {
    Future<void> pump(WidgetTester tester, AppUserProfile viewer, _MockFavouritesRepository favourites) async {
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            userProfileProvider.overrideWith((ref) async => viewer),
            favouritesRepositoryProvider.overrideWithValue(favourites),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: Center(child: FavouriteButton(providerId: 'p1', providerName: 'Glow Studio'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('clients can save a provider', (tester) async {
      final favourites = _MockFavouritesRepository();
      when(() => favourites.getFavouriteProviderIds(_clientId)).thenAnswer((_) async => const []);
      when(() => favourites.addFavourite(clientId: _clientId, providerId: 'p1')).thenAnswer((_) async {});
      await pump(tester, _viewer(_clientId, UserRole.customer), favourites);

      await tester.tap(find.byTooltip('Save to favourites'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove from favourites'), findsOneWidget);
      expect(find.text('Glow Studio saved to your favourites'), findsOneWidget);
    });

    testWidgets('is hidden from providers', (tester) async {
      await pump(tester, _viewer('prov-9', UserRole.provider), _MockFavouritesRepository());
      expect(find.byType(IconButton), findsNothing);
    });
  });
}
