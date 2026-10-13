import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../../customers/provider_profile/views/widgets/section_states.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../shared/bookings/views/widgets/booking_card.dart' show PersonAvatar;
import '../../controllers/post_comments_controller.dart';
import '../../controllers/post_engagement_controller.dart';
import '../../models/comment_failure.dart';
import '../../models/post_comment.dart';
import '../../models/post_model.dart';

/// Opens [post]'s comments in a tall bottom sheet with a box to add one.
Future<void> showPostCommentsSheet(BuildContext context, {required PostModel post}) {
  return showModalBottomSheet<void>(
    context: context,
    // Above the tab bar, which would otherwise cover the comment box.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => PostCommentsSheet(post: post),
  );
}

class PostCommentsSheet extends ConsumerStatefulWidget {
  const PostCommentsSheet({super.key, required this.post});

  final PostModel post;

  @override
  ConsumerState<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends ConsumerState<PostCommentsSheet> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  bool _sending = false;

  PostModel get _post => widget.post;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    // Scroll to the new comment once it's laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
    try {
      await ref.read(postCommentsProvider(_post.id).notifier).add(_post, text);
      HapticFeedback.lightImpact();
    } on CommentFailure catch (failure) {
      // Give the text back so nothing typed is lost.
      if (mounted && _controller.text.isEmpty) _controller.text = text;
      if (mounted) context.showAppSnackBar(failure.message, isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(PostComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text("It will be removed for everyone. This can't be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.destructive),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(postCommentsProvider(_post.id).notifier).delete(_post, comment);
    } on CommentFailure catch (failure) {
      if (mounted) context.showAppSnackBar(failure.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final viewerId = ref.watch(userProfileProvider.select((p) => p.value?.rawUser.id));
    final isPostOwner = viewerId == _post.authorId;
    final canComment = viewerId != null && (_post.tagStatus == 'approved' || isPostOwner);
    final async = ref.watch(postCommentsProvider(_post.id));
    final count = PostEngagementView.of(_post, ref.watch(postEngagementProvider(_post.id))).commentsCount;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Semantics(
              header: true,
              child: Text(
                count == 0 ? 'Comments' : 'Comments · ${Formatters.compactCount(count)}',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: scheme.onSurface),
              ),
            ),
          ),
          Divider(height: 1, color: scheme.onSurface.withValues(alpha: 0.08)),
          Expanded(
            child: switch (async) {
              AsyncData(:final value) when value.items.isEmpty => ListView(
                  children: const [
                    SectionEmptyView(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'No comments yet',
                      message: 'Be the first to say something nice.',
                    ),
                  ],
                ),
              AsyncData(:final value) => ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                  itemCount: value.items.length + (value.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == value.items.length) {
                      return _LoadMoreButton(
                        loading: value.loadingMore,
                        failed: value.loadMoreFailed,
                        onPressed: () => ref.read(postCommentsProvider(_post.id).notifier).loadMore(),
                      );
                    }
                    final comment = value.items[index];
                    final canDelete = !comment.pending && (comment.authorId == viewerId || isPostOwner);
                    return _CommentTile(
                      comment: comment,
                      isPostAuthor: comment.authorId == _post.authorId,
                      onDelete: canDelete ? () => _delete(comment) : null,
                    );
                  },
                ),
              AsyncError(:final error) => ListView(
                  children: [
                    SectionErrorView(
                      title: "Comments didn't load",
                      message: describeLoadError(error, subject: 'the comments'),
                      onRetry: () => ref.invalidate(postCommentsProvider(_post.id)),
                    ),
                  ],
                ),
              _ => Shimmer(
                  child: ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    children: const [ListTileSkeleton(), ListTileSkeleton(), ListTileSkeleton()],
                  ),
                ),
            },
          ),
          Divider(height: 1, color: scheme.onSurface.withValues(alpha: 0.08)),
          AnimatedPadding(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: canComment
                ? _Composer(
                    controller: _controller,
                    focusNode: _focus,
                    sending: _sending,
                    onSend: _send,
                  )
                : Padding(
                    padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.paddingOf(context).bottom),
                    child: Text(
                      'Comments open once this post is published.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.5, color: scheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, required this.isPostAuthor, required this.onDelete});

  final PostComment comment;
  final bool isPostAuthor;

  /// Null when the viewer can't remove it.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.5);
    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PersonAvatar(name: comment.authorName, url: comment.authorAvatarUrl, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: comment.authorName,
                      style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
                    ),
                    if (isPostAuthor)
                      TextSpan(text: '  · Author', style: TextStyle(fontWeight: FontWeight.w600, color: scheme.secondary)),
                    TextSpan(
                      text: comment.pending ? '  · Posting…' : '  · ${Formatters.relativeTime(comment.createdAt)}',
                      style: TextStyle(color: muted),
                    ),
                  ]),
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  comment.content,
                  style: TextStyle(fontSize: 14.5, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.88)),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete comment',
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.delete_outline_rounded, size: 19, color: muted),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
    return Opacity(opacity: comment.pending ? 0.6 : 1, child: tile);
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.loading, required this.failed, required this.onPressed});

  final bool loading;
  final bool failed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: loading
            ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
            : TextButton(
                onPressed: onPressed,
                child: Text(failed ? "Couldn't load more. Try again" : 'Load more comments'),
              ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.focusNode, required this.sending, required this.onSend});

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final length = controller.text.characters.length;
    final nearLimit = length > AppConfig.commentMaxLength - 50;
    final canSend = !sending && controller.text.trim().isNotEmpty && length <= AppConfig.commentMaxLength;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 8, 8 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 4,
              maxLength: AppConfig.commentMaxLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Add a comment…',
                counterText: nearLimit ? '$length/${AppConfig.commentMaxLength}' : '',
                filled: true,
                fillColor: scheme.onSurface.withValues(alpha: 0.04),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: EdgeInsets.only(bottom: nearLimit ? 22 : 0),
            child: IconButton(
              tooltip: 'Post comment',
              onPressed: canSend ? onSend : null,
              icon: Icon(Icons.send_rounded, color: canSend ? scheme.secondary : scheme.onSurface.withValues(alpha: 0.3)),
            ),
          ),
        ],
      ),
    );
  }
}
