import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myglo/src/core/config/app_config.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/customers/favourites/models/favourites_repository.dart';
import 'package:myglo/src/features/discovery_feed/models/post_model.dart';
import 'package:myglo/src/features/discovery_feed/models/post_repository.dart';
import 'package:myglo/src/features/discovery_feed/views/discovery_screen.dart';
import 'package:myglo/src/features/discovery_feed/views/widgets/discover_tile.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_repository.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockPostRepository extends Mock implements PostRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockFavouritesRepository extends Mock implements FavouritesRepository {}

const _clientId = 'client-1';
const _providerId = 'prov-1';
const _author = ProfileModel(id: _providerId, role: UserRole.provider, providerName: 'Glow Studio');

PostModel _post(int i, {String? serviceId, String? caption}) => PostModel(
  id: 'post-$i',
  authorId: _providerId,
  // No media keeps the test off the network image cache.
  mediaUrls: const [],
  caption: caption ?? 'Look number $i',
  serviceId: serviceId,
  tagStatus: 'approved',
  likesCount: 3,
  commentsCount: 0,
  createdAt: DateTime.utc(2026, 9, 30).subtract(Duration(hours: i)),
  updatedAt: DateTime.utc(2026, 9, 30),
);

AppUserProfile _viewer(String id, UserRole role, {LocationCoordinates? coordinates}) => AppUserProfile(
  rawUser: User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
  ),
  role: role,
  profile: ProfileModel(id: id, role: role, firstName: 'Sam', coordinates: coordinates),
);

final _client = _viewer(_clientId, UserRole.customer);
const _goldCoast = LocationCoordinates(type: 'Point', coordinates: [153.43, -28.0]);

/// The Discover tile showing [postId] (captions only render on large tiles).
Finder _tileFor(String postId) =>
    find.byWidgetPredicate((widget) => widget is DiscoverTile && widget.entry.post.id == postId);

class _Mocks {
  final posts = _MockPostRepository();
  final users = _MockUserRepository();
  final favourites = _MockFavouritesRepository();

  _Mocks({List<String> favouriteIds = const []}) {
    when(() => users.getPublicProfiles(any())).thenAnswer((_) async => {_providerId: _author});
    when(() => favourites.getFavouriteProviderIds(any())).thenAnswer((_) async => favouriteIds);
  }

  void feedReturns(List<PostModel> page) {
    when(() => posts.getFeedPage(
          limit: any(named: 'limit'),
          before: any(named: 'before'),
          providerIds: any(named: 'providerIds'),
          excludeAuthorId: any(named: 'excludeAuthorId'),
        )).thenAnswer((_) async => page);
  }

  void nearbyReturns(List<PostModel> page) {
    when(() => posts.getNearbyPage(
          limit: any(named: 'limit'),
          radiusMetres: any(named: 'radiusMetres'),
          before: any(named: 'before'),
        )).thenAnswer((_) async => page);
  }

  void beyondReturns(List<PostModel> page) {
    when(() => posts.getBeyondNearbyPage(
          limit: any(named: 'limit'),
          radiusMetres: any(named: 'radiusMetres'),
          before: any(named: 'before'),
        )).thenAnswer((_) async => page);
  }
}

Future<void> _pump(WidgetTester tester, _Mocks mocks, {AppUserProfile? viewer}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        userProfileProvider.overrideWith((ref) async => viewer ?? _client),
        postRepositoryProvider.overrideWithValue(mocks.posts),
        userRepositoryProvider.overrideWithValue(mocks.users),
        favouritesRepositoryProvider.overrideWithValue(mocks.favourites),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const DiscoveryScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('client', () {
    testWidgets('For you shows each post with its real author and a bookable badge', (tester) async {
      final mocks = _Mocks()..feedReturns([_post(1, serviceId: 'svc-1'), _post(2)]);
      await _pump(tester, mocks);

      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('For you'), findsOneWidget);
      expect(find.text('Favourites'), findsOneWidget);
      expect(find.text('Following'), findsNothing);
      expect(find.text('Glow Studio'), findsNWidgets(2));
      expect(find.text('Bookable'), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
      // A short first page means there is nothing more to load.
      expect(find.text("You're all caught up"), findsOneWidget);
    });

    testWidgets('Favourites explains how to fill it when nothing is saved', (tester) async {
      final mocks = _Mocks()..feedReturns([_post(1)]);
      await _pump(tester, mocks);
      await tester.tap(find.text('Favourites'));
      await tester.pumpAndSettle();

      expect(find.text('Save the salons you love'), findsOneWidget);
      verifyNever(() => mocks.posts.getFeedPage(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
            providerIds: any(named: 'providerIds', that: isNotNull),
            excludeAuthorId: any(named: 'excludeAuthorId'),
          ));

      await tester.tap(find.text('Explore For you'));
      await tester.pumpAndSettle();
      expect(find.text('Glow Studio'), findsOneWidget);
    });

    testWidgets('Favourites lists posts for saved providers in the bento grid', (tester) async {
      final mocks = _Mocks(favouriteIds: [_providerId])..feedReturns([_post(1, serviceId: 'svc-1')]);
      await _pump(tester, mocks);
      await tester.tap(find.text('Favourites'));
      await tester.pumpAndSettle();

      verify(() => mocks.posts.getFeedPage(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
            providerIds: [_providerId],
            excludeAuthorId: any(named: 'excludeAuthorId'),
          )).called(1);
      // A lone post closes the feed as one full-width tile with its caption.
      expect(find.text('Look number 1'), findsOneWidget);
      expect(find.text('Bookable'), findsOneWidget);
    });

    testWidgets('a failed load offers a retry that recovers', (tester) async {
      final mocks = _Mocks();
      var offline = true;
      when(() => mocks.posts.getFeedPage(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
            providerIds: any(named: 'providerIds'),
            excludeAuthorId: any(named: 'excludeAuthorId'),
          )).thenAnswer((_) async {
        if (offline) throw Exception('boom');
        return [_post(1)];
      });

      await _pump(tester, mocks);
      expect(find.text("Discover didn't load"), findsOneWidget);

      offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Glow Studio'), findsOneWidget);
    });

    testWidgets('scrolling near the end loads the next page from the oldest post', (tester) async {
      final mocks = _Mocks();
      final firstPage = [for (var i = 0; i < AppConfig.discoverPageSize; i++) _post(i)];
      when(() => mocks.posts.getFeedPage(
            limit: any(named: 'limit'),
            before: null,
            providerIds: any(named: 'providerIds'),
            excludeAuthorId: any(named: 'excludeAuthorId'),
          )).thenAnswer((_) async => firstPage);
      when(() => mocks.posts.getFeedPage(
            limit: any(named: 'limit'),
            before: firstPage.last.createdAt,
            providerIds: any(named: 'providerIds'),
            excludeAuthorId: any(named: 'excludeAuthorId'),
          )).thenAnswer((_) async => [_post(100)]);

      await _pump(tester, mocks);
      await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -5000));
      await tester.pumpAndSettle();

      verify(() => mocks.posts.getFeedPage(
            limit: any(named: 'limit'),
            before: firstPage.last.createdAt,
            providerIds: any(named: 'providerIds'),
            excludeAuthorId: any(named: 'excludeAuthorId'),
          )).called(1);
      expect(find.text("You're all caught up"), findsOneWidget);
    });
  });

  group('provider', () {
    const providerViewerId = 'prov-viewer';

    testWidgets('sees nearby posts with no tabs', (tester) async {
      final mocks = _Mocks()
        ..nearbyReturns([_post(1), _post(2), _post(3)])
        ..beyondReturns(const []);
      await _pump(
        tester,
        mocks,
        viewer: _viewer(providerViewerId, UserRole.provider, coordinates: _goldCoast),
      );

      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('For you'), findsNothing);
      expect(find.text('Favourites'), findsNothing);
      expect(find.text('Within 25 km of your business'), findsOneWidget);
      // One tall tile and two squares, each with its author.
      expect(find.text('Glow Studio'), findsNWidgets(3));
      verifyNever(() => mocks.posts.getFeedPage(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
            providerIds: any(named: 'providerIds'),
            excludeAuthorId: any(named: 'excludeAuthorId'),
          ));
      verifyNever(() => mocks.favourites.getFavouriteProviderIds(any()));
      // Nothing beyond the radius either: no empty heading, just the end.
      expect(find.text('More from across Myglo'), findsNothing);
      expect(find.text("You're all caught up"), findsOneWidget);
    });

    testWidgets('carries on with posts from further away once nearby posts run out', (tester) async {
      final mocks = _Mocks()
        ..nearbyReturns([_post(1, caption: 'Nearby look')])
        ..beyondReturns([_post(2), _post(3), _post(4)]);
      await _pump(
        tester,
        mocks,
        viewer: _viewer(providerViewerId, UserRole.provider, coordinates: _goldCoast),
      );

      expect(find.text('Within 25 km of your business'), findsOneWidget);
      expect(find.text('Nearby look'), findsOneWidget);
      expect(find.text('More from across Myglo'), findsOneWidget);
      expect(find.text('Looks from further than 25 km away'), findsOneWidget);
      expect(find.text('Nothing nearby yet'), findsNothing);
      // The far-away posts are paged from their own start, with the same radius.
      verify(() => mocks.posts.getBeyondNearbyPage(
            limit: AppConfig.discoverPageSize,
            radiusMetres: AppConfig.nearbyRadiusMetres,
            before: null,
          )).called(1);
      // The nearby post closes its own grid above the heading.
      expect(
        tester.getTopLeft(find.text('Nearby look')).dy,
        lessThan(tester.getTopLeft(find.text('More from across Myglo')).dy),
      );
      await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      for (final id in ['post-2', 'post-3', 'post-4']) {
        expect(_tileFor(id), findsOneWidget);
      }
      expect(find.text("You're all caught up"), findsOneWidget);
    });

    testWidgets('pages nearby posts first, then pages the rest from their own cursor', (tester) async {
      final mocks = _Mocks();
      final nearby = [for (var i = 0; i < AppConfig.discoverPageSize; i++) _post(i)];
      final beyond = [for (var i = 0; i < AppConfig.discoverPageSize; i++) _post(100 + i)];
      when(() => mocks.posts.getNearbyPage(
            limit: any(named: 'limit'),
            radiusMetres: any(named: 'radiusMetres'),
            before: null,
          )).thenAnswer((_) async => nearby);
      when(() => mocks.posts.getNearbyPage(
            limit: any(named: 'limit'),
            radiusMetres: any(named: 'radiusMetres'),
            before: nearby.last.createdAt,
          )).thenAnswer((_) async => const []);
      when(() => mocks.posts.getBeyondNearbyPage(
            limit: any(named: 'limit'),
            radiusMetres: any(named: 'radiusMetres'),
            before: null,
          )).thenAnswer((_) async => beyond);
      when(() => mocks.posts.getBeyondNearbyPage(
            limit: any(named: 'limit'),
            radiusMetres: any(named: 'radiusMetres'),
            before: beyond.last.createdAt,
          )).thenAnswer((_) async => [_post(500)]);

      await _pump(
        tester,
        mocks,
        viewer: _viewer(providerViewerId, UserRole.provider, coordinates: _goldCoast),
      );
      // A full nearby page: the rest isn't needed yet.
      verifyNever(() => mocks.posts.getBeyondNearbyPage(
            limit: any(named: 'limit'),
            radiusMetres: any(named: 'radiusMetres'),
            before: any(named: 'before'),
          ));

      for (var i = 0; i < 12 && find.text("You're all caught up").evaluate().isEmpty; i++) {
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -3000));
        await tester.pumpAndSettle();
      }

      verify(() => mocks.posts.getNearbyPage(
            limit: any(named: 'limit'),
            radiusMetres: any(named: 'radiusMetres'),
            before: nearby.last.createdAt,
          )).called(1);
      verify(() => mocks.posts.getBeyondNearbyPage(
            limit: any(named: 'limit'),
            radiusMetres: any(named: 'radiusMetres'),
            before: null,
          )).called(1);
      verify(() => mocks.posts.getBeyondNearbyPage(
            limit: any(named: 'limit'),
            radiusMetres: any(named: 'radiusMetres'),
            before: beyond.last.createdAt,
          )).called(1);
      expect(_tileFor('post-500'), findsOneWidget);
      expect(find.text('More from across Myglo', skipOffstage: false), findsOneWidget);
      expect(find.text("You're all caught up"), findsOneWidget);
    });

    testWidgets('keeps nearby posts and offers a retry when the rest fail to load', (tester) async {
      final mocks = _Mocks()..nearbyReturns([_post(1, caption: 'Nearby look')]);
      var offline = true;
      when(() => mocks.posts.getBeyondNearbyPage(
            limit: any(named: 'limit'),
            radiusMetres: any(named: 'radiusMetres'),
            before: any(named: 'before'),
          )).thenAnswer((_) async {
        if (offline) throw Exception('boom');
        return [_post(2, caption: 'Far look')];
      });
      await _pump(
        tester,
        mocks,
        viewer: _viewer(providerViewerId, UserRole.provider, coordinates: _goldCoast),
      );

      expect(find.text('Nearby look'), findsOneWidget);
      expect(find.text("Couldn't load more posts"), findsOneWidget);
      expect(find.text("Discover didn't load"), findsNothing);

      offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('More from across Myglo'), findsOneWidget);
      expect(find.text('Far look'), findsOneWidget);
      // Retried from the start of the far-away posts, not the nearby cursor.
      verify(() => mocks.posts.getBeyondNearbyPage(
            limit: any(named: 'limit'),
            radiusMetres: any(named: 'radiusMetres'),
            before: null,
          )).called(2);
    });

    testWidgets('without an address sees recent posts and a prompt to add one', (tester) async {
      final mocks = _Mocks()..feedReturns([_post(1)]);
      await _pump(tester, mocks, viewer: _viewer(providerViewerId, UserRole.provider));

      expect(find.text('Add address'), findsOneWidget);
      verify(() => mocks.posts.getFeedPage(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
            providerIds: null,
            excludeAuthorId: providerViewerId,
          )).called(1);
      verifyNever(() => mocks.posts.getNearbyPage(
            limit: any(named: 'limit'),
            radiusMetres: any(named: 'radiusMetres'),
            before: any(named: 'before'),
          ));
    });

    testWidgets('shows posts from further away when nothing nearby has been posted', (tester) async {
      final mocks = _Mocks()
        ..nearbyReturns(const [])
        ..beyondReturns([_post(1)]);
      await _pump(
        tester,
        mocks,
        viewer: _viewer(providerViewerId, UserRole.provider, coordinates: _goldCoast),
      );

      expect(find.text('Nothing nearby yet'), findsOneWidget);
      expect(find.text('Glow Studio'), findsOneWidget);
      // The notice already explains it; no second heading.
      expect(find.text('More from across Myglo'), findsNothing);
      verifyNever(() => mocks.posts.getFeedPage(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
            providerIds: any(named: 'providerIds'),
            excludeAuthorId: any(named: 'excludeAuthorId'),
          ));
    });

    testWidgets('shows the error state when nothing nearby and the rest fail to load', (tester) async {
      final mocks = _Mocks()..nearbyReturns(const []);
      when(() => mocks.posts.getBeyondNearbyPage(
            limit: any(named: 'limit'),
            radiusMetres: any(named: 'radiusMetres'),
            before: any(named: 'before'),
          )).thenThrow(Exception('boom'));
      await _pump(
        tester,
        mocks,
        viewer: _viewer(providerViewerId, UserRole.provider, coordinates: _goldCoast),
      );

      expect(find.text("Discover didn't load"), findsOneWidget);
    });
  });
}
