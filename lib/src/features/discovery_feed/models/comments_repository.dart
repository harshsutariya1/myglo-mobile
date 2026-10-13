import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_logger.dart';
import '../../shared/authentication/models/auth_repository.dart';
import 'comment_failure.dart';
import 'post_comment.dart';

final commentsRepositoryProvider = Provider<CommentsRepository>((ref) {
  return CommentsRepository(ref.watch(supabaseClientProvider));
});

/// Postgres `unique_violation` SQLSTATE.
const _uniqueViolation = '23505';

/// Comments on posts. Row-level security limits them to posts the viewer can
/// see; the database trims the text, stamps the time, rate-limits authors and
/// keeps `posts.comments_count` in step.
class CommentsRepository {
  CommentsRepository(this._client);

  final SupabaseClient _client;

  static const _tag = 'CommentsRepository';

  /// One page of [postId]'s comments, oldest first. Pass the last comment
  /// already shown as [after] for the next page.
  Future<List<PostComment>> list(String postId, {required int limit, PostComment? after}) async {
    final sw = Stopwatch()..start();
    try {
      final rows = await _client.rpc('list_post_comments', params: {
        'p_post_id': postId,
        'p_after': after?.createdAt.toUtc().toIso8601String(),
        'p_after_id': after?.id,
        'p_limit': limit,
      }) as List<dynamic>;
      sw.stop();
      AppLogger.api('rpc.list_post_comments', count: rows.length, duration: sw.elapsed);
      return [for (final row in rows) PostComment.fromJson(Map<String, dynamic>.from(row as Map))];
    } catch (e, st) {
      AppLogger.e('Failed to load comments for post $postId', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Adds a comment as [authorId]. Pass the same [id] when retrying: if the
  /// first attempt reached the database, the retry counts as success.
  /// Throws a [CommentFailure].
  Future<void> add({
    required String id,
    required String postId,
    required String authorId,
    required String content,
  }) async {
    final sw = Stopwatch()..start();
    try {
      await _client.from('comments').insert({
        'id': id,
        'post_id': postId,
        'author_id': authorId,
        'content': content,
      });
      sw.stop();
      AppLogger.api('comments.insert', endpoint: 'post=$postId', duration: sw.elapsed);
    } on PostgrestException catch (e, st) {
      if (e.code == _uniqueViolation) {
        AppLogger.w('Comment $id already exists; treating retry as success', tag: _tag);
        return;
      }
      throwCommentError(e, st, action: 'Adding a comment');
    } catch (e, st) {
      throwCommentError(e, st, action: 'Adding a comment');
    }
  }

  /// Deletes a comment. Its author, or the post's author, may do this.
  /// Throws a [CommentFailure].
  Future<void> delete(String commentId) async {
    final sw = Stopwatch()..start();
    try {
      final deleted = await _client.from('comments').delete().eq('id', commentId).select('id');
      sw.stop();
      AppLogger.api('comments.delete', endpoint: 'id=$commentId', duration: sw.elapsed);
      // Nothing deleted: already gone, or not the viewer's to remove.
      if ((deleted as List).isEmpty) {
        AppLogger.w('Comment $commentId was not deleted (missing or not allowed)', tag: _tag);
      }
    } catch (e, st) {
      throwCommentError(e, st, action: 'Deleting a comment');
    }
  }
}
