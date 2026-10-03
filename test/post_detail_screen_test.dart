import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/discovery_feed/controllers/post_detail_controller.dart';
import 'package:myglo/src/features/discovery_feed/models/post_model.dart';
import 'package:myglo/src/features/discovery_feed/models/post_repository.dart';
import 'package:myglo/src/features/discovery_feed/views/post_detail_screen.dart';
import 'package:myglo/src/features/providers/provider_profiles/controllers/provider_services_controller.dart';
import 'package:myglo/src/features/providers/provider_profiles/models/service_model.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockPostRepository extends Mock implements PostRepository {}

const _providerId = 'prov-1';

const _author = ProfileModel(id: _providerId, role: UserRole.provider, providerName: 'Glow Studio');

final _service = ServiceModel(
  id: 'svc-1',
  providerId: _providerId,
  name: 'Lash lift',
  description: '',
  price: 85,
  durationMinutes: 60,
  createdAt: DateTime.utc(2026, 9, 1),
);

PostModel _post({String? caption = 'Fresh lift for summer #lashes', String? serviceId = 'svc-1'}) => PostModel(
  id: 'post-1',
  authorId: _providerId,
  // No media keeps the test off the network image cache.
  mediaUrls: const [],
  caption: caption,
  serviceId: serviceId,
  tagStatus: 'approved',
  likesCount: 12,
  commentsCount: 0,
  createdAt: DateTime.utc(2026, 9, 30),
  updatedAt: DateTime.utc(2026, 9, 30),
);

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

Future<_MockPostRepository> _pump(WidgetTester tester, {required PostModel post, required AppUserProfile viewer}) async {
  // Phone-sized viewport, so the content under the 4:5 media is on screen.
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repository = _MockPostRepository();
  when(() => repository.hasLiked(postId: any(named: 'postId'), userId: any(named: 'userId')))
      .thenAnswer((_) async => false);
  when(() => repository.likePost(postId: any(named: 'postId'), userId: any(named: 'userId'))).thenAnswer((_) async {});
  when(() => repository.unlikePost(postId: any(named: 'postId'), userId: any(named: 'userId'))).thenAnswer((_) async {});

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        userProfileProvider.overrideWith((ref) async => viewer),
        postRepositoryProvider.overrideWithValue(repository),
        postProfileProvider(_providerId).overrideWith((ref) async => _author),
        serviceByIdProvider('svc-1').overrideWith((ref) async => _service),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: PostDetailScreen(post: post)),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('client sees author, caption, tagged service and a booking bar', (tester) async {
    await _pump(tester, post: _post(), viewer: _viewer('client-1', UserRole.customer));

    expect(find.text('Glow Studio'), findsNWidgets(2)); // Top bar and quick card.
    expect(find.textContaining('Fresh lift for summer', findRichText: true), findsOneWidget);
    expect(find.text(r'Lash lift — $85'), findsOneWidget);
    expect(find.text('Book this look'), findsOneWidget);
    expect(find.text('New · No reviews yet'), findsOneWidget);
  });

  testWidgets('without a linked service the client can inquire instead', (tester) async {
    await _pump(tester, post: _post(serviceId: null), viewer: _viewer('client-1', UserRole.customer));

    expect(find.text('Inquire'), findsOneWidget);
    expect(find.text('TAGGED SERVICE'), findsNothing);
  });

  testWidgets('providers never see the booking bar', (tester) async {
    await _pump(tester, post: _post(), viewer: _viewer('other-provider', UserRole.provider));

    expect(find.text('Book this look'), findsNothing);
    expect(find.text('Inquire'), findsNothing);
  });

  testWidgets('liking updates the count immediately and saves it', (tester) async {
    final repository = await _pump(tester, post: _post(), viewer: _viewer('client-1', UserRole.customer));
    expect(find.text('12'), findsOneWidget);

    await tester.tap(find.byTooltip('Like'));
    await tester.pumpAndSettle();

    expect(find.text('13'), findsOneWidget);
    expect(find.byTooltip('Unlike'), findsOneWidget);
    verify(() => repository.likePost(postId: 'post-1', userId: 'client-1')).called(1);
  });

  testWidgets('a failed like rolls back and tells the user', (tester) async {
    final repository = await _pump(tester, post: _post(), viewer: _viewer('client-1', UserRole.customer));
    when(() => repository.likePost(postId: any(named: 'postId'), userId: any(named: 'userId')))
        .thenThrow(Exception('offline'));

    await tester.tap(find.byTooltip('Like'));
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
    expect(find.byTooltip('Like'), findsOneWidget);
    expect(find.text("Couldn't save your like. Please try again."), findsOneWidget);
  });

  testWidgets('only the owner can delete; others can report', (tester) async {
    await _pump(tester, post: _post(), viewer: _viewer(_providerId, UserRole.provider));
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Delete post'), findsOneWidget);
    expect(find.text('Report post'), findsNothing);
  });

  testWidgets('non-owners can report but not delete', (tester) async {
    await _pump(tester, post: _post(), viewer: _viewer('client-1', UserRole.customer));
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Report post'), findsOneWidget);
    expect(find.text('Delete post'), findsNothing);
  });

  testWidgets('long captions collapse with an inline more/less toggle', (tester) async {
    final long = List.filled(40, 'Soft glam with a glossy finish.').join(' ');
    await _pump(tester, post: _post(caption: long), viewer: _viewer('client-1', UserRole.customer));

    expect(find.textContaining('… more', findRichText: true), findsOneWidget);

    await tester.tap(find.textContaining('… more', findRichText: true));
    await tester.pumpAndSettle();

    expect(find.textContaining('  less', findRichText: true), findsOneWidget);
  });

  testWidgets('owner can delete a post: it succeeds, closes and confirms', (tester) async {
    // Regression: the auto-dispose delete controller used to be disposed
    // mid-request, so a successful delete was reported as a failure.
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = _MockPostRepository();
    when(() => repository.hasLiked(postId: any(named: 'postId'), userId: any(named: 'userId')))
        .thenAnswer((_) async => false);
    when(() => repository.deletePost(any(), any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref) async => _viewer(_providerId, UserRole.provider)),
          postRepositoryProvider.overrideWithValue(repository),
          postProfileProvider(_providerId).overrideWith((ref) async => _author),
          serviceByIdProvider('svc-1').overrideWith((ref) async => _service),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PostDetailScreen(post: _post())),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete post'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => repository.deletePost('post-1', const [])).called(1);
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Post deleted'), findsOneWidget);
    expect(find.textContaining("Couldn't delete"), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
