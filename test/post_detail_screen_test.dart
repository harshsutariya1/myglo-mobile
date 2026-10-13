import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/core/platform/system_bridge.dart';
import 'package:myglo/src/features/discovery_feed/controllers/post_detail_controller.dart';
import 'package:myglo/src/features/discovery_feed/models/comments_repository.dart';
import 'package:myglo/src/features/discovery_feed/models/post_comment.dart';
import 'package:myglo/src/features/discovery_feed/models/post_engagement.dart';
import 'package:myglo/src/features/discovery_feed/models/post_model.dart';
import 'package:myglo/src/features/discovery_feed/models/post_repository.dart';
import 'package:myglo/src/features/discovery_feed/views/post_detail_screen.dart';
import 'package:myglo/src/features/providers/provider_profiles/controllers/provider_services_controller.dart';
import 'package:myglo/src/features/providers/provider_profiles/models/service_model.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:myglo/src/features/shared/reviews/controllers/reviews_controllers.dart';
import 'package:myglo/src/features/shared/reviews/models/review_summary.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockPostRepository extends Mock implements PostRepository {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _FakeSystem implements SystemBridge {
  final shared = <Uri>[];

  @override
  Future<bool> mapsAvailable() async => true;

  @override
  Future<bool> notificationsEnabled() async => true;

  @override
  Future<bool> openNotificationSettings() async => true;

  @override
  Future<bool> share({required String text, required Uri url, String? subject, Rect? origin}) async {
    shared.add(url);
    return true;
  }

  @override
  Future<bool> openUrl(Uri url, {Uri? appUrl, String? appPackage}) async => true;
}

PostEngagement _engagement({int likes = 12, int comments = 0, bool liked = false}) =>
    PostEngagement(likesCount: likes, commentsCount: comments, liked: liked, updatedAt: DateTime.now());

/// Mocks a post repository whose server holds [likes] likes, applying likes
/// the way `set_post_like` does.
void _stubLikes(_MockPostRepository repository, {int likes = 12, bool liked = false}) {
  var serverLikes = likes;
  var serverLiked = liked;
  when(() => repository.getEngagement(any())).thenAnswer((_) async => _engagement(likes: serverLikes, liked: serverLiked));
  when(() => repository.setLiked(postId: any(named: 'postId'), liked: any(named: 'liked'))).thenAnswer((call) async {
    final want = call.namedArguments[#liked] as bool;
    if (want != serverLiked) serverLikes += want ? 1 : -1;
    serverLiked = want;
    return serverLikes;
  });
}

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

Future<_MockPostRepository> _pump(
  WidgetTester tester, {
  required PostModel post,
  required AppUserProfile viewer,
  _MockCommentsRepository? comments,
  _FakeSystem? system,
}) async {
  // Phone-sized viewport, so the content under the 4:5 media is on screen.
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repository = _MockPostRepository();
  _stubLikes(repository);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        userProfileProvider.overrideWith((ref) async => viewer),
        postRepositoryProvider.overrideWithValue(repository),
        commentsRepositoryProvider.overrideWithValue(comments ?? _MockCommentsRepository()),
        systemBridgeProvider.overrideWithValue(system ?? _FakeSystem()),
        postProfileProvider(_providerId).overrideWith((ref) async => _author),
        serviceByIdProvider('svc-1').overrideWith((ref) async => _service),
        providerReviewSummaryProvider(_providerId).overrideWith((ref) async => ReviewSummary.empty),
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
    verify(() => repository.setLiked(postId: 'post-1', liked: true)).called(1);
  });

  testWidgets('opening a post shows its live counts, not the stale ones it arrived with', (tester) async {
    // The feed page said 12; since then the server has 20 and the viewer's like.
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _MockPostRepository();
    when(() => repository.getEngagement(any())).thenAnswer((_) async => _engagement(likes: 20, comments: 3, liked: true));

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          userProfileProvider.overrideWith((ref) async => _viewer('client-1', UserRole.customer)),
          postRepositoryProvider.overrideWithValue(repository),
          postProfileProvider(_providerId).overrideWith((ref) async => _author),
          serviceByIdProvider('svc-1').overrideWith((ref) async => _service),
          providerReviewSummaryProvider(_providerId).overrideWith((ref) async => ReviewSummary.empty),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme, home: PostDetailScreen(post: _post())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('20'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byTooltip('Unlike'), findsOneWidget);
    expect(find.text('View all 3 comments'), findsOneWidget);
  });

  testWidgets('rapid like/unlike taps settle on the last choice', (tester) async {
    final repository = await _pump(tester, post: _post(), viewer: _viewer('client-1', UserRole.customer));

    await tester.tap(find.byTooltip('Like'));
    await tester.pump();
    await tester.tap(find.byTooltip('Unlike'));
    await tester.pump();
    await tester.tap(find.byTooltip('Like'));
    await tester.pumpAndSettle();

    expect(find.text('13'), findsOneWidget);
    expect(find.byTooltip('Unlike'), findsOneWidget);
    // Whatever was sent in between, the server ends on "liked".
    final calls = verify(() => repository.setLiked(postId: 'post-1', liked: captureAny(named: 'liked'))).captured;
    expect(calls.last, isTrue);
  });

  testWidgets('a failed like rolls back and tells the user', (tester) async {
    final repository = await _pump(tester, post: _post(), viewer: _viewer('client-1', UserRole.customer));
    when(() => repository.setLiked(postId: any(named: 'postId'), liked: any(named: 'liked')))
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
    _stubLikes(repository);
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
          providerReviewSummaryProvider(_providerId).overrideWith((ref) async => ReviewSummary.empty),
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

  testWidgets('comments: the sheet lists them and posts a new one at once', (tester) async {
    final comments = _MockCommentsRepository();
    final existing = PostComment(
      id: 'c-1',
      postId: 'post-1',
      authorId: _providerId,
      authorName: 'Glow Studio',
      content: 'Thanks for coming in!',
      createdAt: DateTime.utc(2026, 9, 30, 10),
    );
    when(() => comments.list('post-1', limit: any(named: 'limit'), after: any(named: 'after')))
        .thenAnswer((_) async => [existing]);
    when(() => comments.add(
          id: any(named: 'id'),
          postId: any(named: 'postId'),
          authorId: any(named: 'authorId'),
          content: any(named: 'content'),
        )).thenAnswer((_) async {});

    await _pump(tester, post: _post(), viewer: _viewer('client-1', UserRole.customer), comments: comments);

    await tester.tap(find.byTooltip('Comments'));
    await tester.pumpAndSettle();
    expect(find.text('Thanks for coming in!'), findsOneWidget);
    expect(find.textContaining('Author', findRichText: true), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  Love this  ');
    await tester.pump();
    await tester.tap(find.byTooltip('Post comment'));
    await tester.pumpAndSettle();

    expect(find.text('Love this'), findsOneWidget);
    verify(() => comments.add(
          id: any(named: 'id'),
          postId: 'post-1',
          authorId: 'client-1',
          content: 'Love this',
        )).called(1);
    // The comment count beside the icon moved with it.
    expect(find.text('Comments · 1'), findsOneWidget);
  });

  testWidgets('sharing a post sends its public link to the share sheet', (tester) async {
    final system = _FakeSystem();
    await _pump(tester, post: _post(), viewer: _viewer('client-1', UserRole.customer), system: system);

    await tester.tap(find.byTooltip('Share'));
    await tester.pumpAndSettle();

    expect(system.shared, [Uri.parse('https://myglo.app/p/post-1')]);
  });
}
