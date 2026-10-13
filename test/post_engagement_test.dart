import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myglo/src/features/discovery_feed/controllers/post_comments_controller.dart';
import 'package:myglo/src/features/discovery_feed/controllers/post_engagement_controller.dart';
import 'package:myglo/src/features/discovery_feed/models/comment_failure.dart';
import 'package:myglo/src/features/discovery_feed/models/comments_repository.dart';
import 'package:myglo/src/features/discovery_feed/models/post_comment.dart';
import 'package:myglo/src/features/discovery_feed/models/post_engagement.dart';
import 'package:myglo/src/features/discovery_feed/models/post_model.dart';
import 'package:myglo/src/features/discovery_feed/models/post_repository.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockPosts extends Mock implements PostRepository {}

class _MockComments extends Mock implements CommentsRepository {}

final _viewer = AppUserProfile(
  rawUser: User(
    id: 'client-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
  ),
  role: UserRole.customer,
  profile: const ProfileModel(id: 'client-1', role: UserRole.customer, firstName: 'Sam', lastName: 'Lee'),
);

final _post = PostModel(
  id: 'post-1',
  authorId: 'prov-1',
  mediaUrls: const [],
  tagStatus: 'approved',
  likesCount: 4,
  commentsCount: 0,
  createdAt: DateTime.utc(2026, 9, 30),
  updatedAt: DateTime.utc(2026, 9, 30),
);

PostComment _comment(int n) => PostComment(
      id: 'c-$n',
      postId: 'post-1',
      authorId: 'other',
      authorName: 'Other',
      content: 'Comment $n',
      createdAt: DateTime.utc(2026, 10, 1, 0, n),
    );

Future<ProviderContainer> _container({PostRepository? posts, CommentsRepository? comments}) async {
  final container = ProviderContainer.test(
    overrides: [
      userProfileProvider.overrideWith((ref) async => _viewer),
      if (posts != null) postRepositoryProvider.overrideWithValue(posts),
      if (comments != null) commentsRepositoryProvider.overrideWithValue(comments),
    ],
  );
  container.listen(postEngagementStoreProvider, (_, _) {});
  await container.read(userProfileProvider.future);
  return container;
}

void main() {
  group('engagement store', () {
    test('a like shows at once and then adopts the server count', () async {
      final posts = _MockPosts();
      final server = Completer<int>();
      when(() => posts.setLiked(postId: 'post-1', liked: true)).thenAnswer((_) => server.future);
      final container = await _container(posts: posts);
      final store = container.read(postEngagementStoreProvider.notifier);

      final saved = store.setLiked(_post, true);
      expect(container.read(postEngagementProvider('post-1'))?.likesCount, 5);
      expect(container.read(postEngagementProvider('post-1'))?.liked, isTrue);

      // Someone else liked it meanwhile.
      server.complete(6);
      expect(await saved, isTrue);
      expect(container.read(postEngagementProvider('post-1'))?.likesCount, 6);
    });

    test('a failed save restores what was shown', () async {
      final posts = _MockPosts();
      when(() => posts.setLiked(postId: 'post-1', liked: true)).thenThrow(Exception('offline'));
      final container = await _container(posts: posts);

      final ok = await container.read(postEngagementStoreProvider.notifier).setLiked(_post, true);

      expect(ok, isFalse);
      final shown = container.read(postEngagementProvider('post-1'))!;
      expect(shown.likesCount, 4);
      expect(shown.liked, isNot(isTrue));
    });

    test('a refresh during a save keeps the pending choice', () async {
      final posts = _MockPosts();
      final server = Completer<int>();
      when(() => posts.setLiked(postId: 'post-1', liked: true)).thenAnswer((_) => server.future);
      when(() => posts.getEngagement('post-1')).thenAnswer(
        (_) async => PostEngagement(likesCount: 4, commentsCount: 2, liked: false, updatedAt: DateTime.now()),
      );
      final container = await _container(posts: posts);
      final store = container.read(postEngagementStoreProvider.notifier);

      final saving = store.setLiked(_post, true);
      await store.refresh('post-1');
      final during = container.read(postEngagementProvider('post-1'))!;
      expect(during.liked, isTrue);
      expect(during.likesCount, 5);
      expect(during.commentsCount, 2);

      server.complete(5);
      await saving;
      expect(container.read(postEngagementProvider('post-1'))!.likesCount, 5);
    });

    test('recent counts win over the ones a feed page arrived with; stale ones do not', () {
      final fresh = PostEngagement(likesCount: 9, commentsCount: 1, updatedAt: DateTime(2026, 10, 13, 12));
      expect(PostEngagementView.of(_post, fresh, now: DateTime(2026, 10, 13, 12, 5)).likesCount, 9);
      expect(PostEngagementView.of(_post, fresh, now: DateTime(2026, 10, 13, 13)).likesCount, 4);
      expect(PostEngagementView.of(_post, null).likesCount, 4);
    });
  });

  group('comments', () {
    test("loading older pages keeps the viewer's new comment last and skips nothing", () async {
      final comments = _MockComments();
      final page1 = [for (var i = 0; i < 30; i++) _comment(i)];
      final page2 = [_comment(30), _comment(31)];
      when(() => comments.list('post-1', limit: any(named: 'limit'))).thenAnswer((_) async => page1);
      when(() => comments.list('post-1', limit: any(named: 'limit'), after: page1.last)).thenAnswer((_) async => page2);
      when(() => comments.add(
            id: any(named: 'id'),
            postId: any(named: 'postId'),
            authorId: any(named: 'authorId'),
            content: any(named: 'content'),
          )).thenAnswer((_) async {});
      final container = await _container(comments: comments);
      container.listen(postCommentsProvider('post-1'), (_, _) {});
      await container.read(postCommentsProvider('post-1').future);

      await container.read(postCommentsProvider('post-1').notifier).add(_post, 'Mine');
      await container.read(postCommentsProvider('post-1').notifier).loadMore();

      final items = container.read(postCommentsProvider('post-1')).value!.items;
      expect(items.map((c) => c.content).toList().sublist(28), ['Comment 28', 'Comment 29', 'Comment 30', 'Comment 31', 'Mine']);
      expect(items.last.authorName, 'Sam Lee');
      expect(items.last.pending, isFalse);
      expect(container.read(postEngagementProvider('post-1'))!.commentsCount, 1);
    });

    test('a refused comment is taken back out and explained', () async {
      final comments = _MockComments();
      when(() => comments.list('post-1', limit: any(named: 'limit'))).thenAnswer((_) async => const []);
      when(() => comments.add(
            id: any(named: 'id'),
            postId: any(named: 'postId'),
            authorId: any(named: 'authorId'),
            content: any(named: 'content'),
          )).thenThrow(const CommentFailure(CommentFailureCode.rateLimited));
      final container = await _container(comments: comments);
      container.listen(postCommentsProvider('post-1'), (_, _) {});
      await container.read(postCommentsProvider('post-1').future);

      await expectLater(
        container.read(postCommentsProvider('post-1').notifier).add(_post, 'Spam'),
        throwsA(isA<CommentFailure>().having((f) => f.message, 'message', contains('wait a moment'))),
      );
      expect(container.read(postCommentsProvider('post-1')).value!.items, isEmpty);
      expect(container.read(postEngagementProvider('post-1'))!.commentsCount, 0);
    });

    test('database refusals map to readable reasons', () {
      expect(
        CommentFailure.from(const PostgrestException(message: 'comment_rate_limited', code: 'P0001')).code,
        CommentFailureCode.rateLimited,
      );
      expect(CommentFailure.from(const PostgrestException(message: 'check', code: '23514')).code, CommentFailureCode.invalidLength);
      expect(CommentFailure.from(const PostgrestException(message: 'rls', code: '42501')).code, CommentFailureCode.notAllowed);
    });
  });
}
