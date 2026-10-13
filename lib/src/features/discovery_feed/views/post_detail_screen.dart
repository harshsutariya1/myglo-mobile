import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/sharing/share_links.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/skeleton/skeletons.dart';
import '../../../core/widgets/snackbar_utils.dart';
import '../../customers/provider_profile/views/widgets/provider_action_sheets.dart';
import '../../providers/provider_profiles/controllers/provider_services_controller.dart';
import '../../providers/provider_profiles/models/service_model.dart';
import '../../shared/authentication/controllers/user_profile_provider.dart';
import '../../shared/authentication/models/profile_model.dart';
import '../../shared/authentication/models/user_role.dart';
import '../../shared/reviews/views/widgets/rating_summary.dart';
import '../../shared/services/views/widgets/service_details_sheet.dart';
import '../controllers/delete_post_controller.dart';
import '../controllers/post_detail_controller.dart';
import '../controllers/post_engagement_controller.dart';
import '../models/post_model.dart';
import 'widgets/post_comments_sheet.dart';
import 'widgets/post_widgets.dart';

/// Full view of one post: media carousel, engagement, caption and the
/// service it shows, with a booking shortcut for clients.
class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({super.key, required this.post, this.onBack});

  final PostModel post;

  /// Replaces the back button's default pop (e.g. for a post opened from a
  /// link with nothing underneath).
  final VoidCallback? onBack;

  static const double _barHeight = 56;

  /// The provider the post promotes: its author when the author is a
  /// provider, otherwise the provider a client tagged (once they approved).
  static String? _providerIdFor(PostModel post, ProfileModel? author) {
    if (author?.role == UserRole.provider) return post.authorId;
    if (post.tagStatus == 'approved') return post.taggedProviderId;
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the auto-dispose delete controller alive for as long as this
    // screen is open, so a delete in flight can finish and refresh the grid.
    final deleting = ref.watch(deletePostControllerProvider).isLoading;
    final viewer = ref.watch(userProfileProvider).value;
    final isOwner = viewer?.rawUser.id == post.authorId;
    final isClient = viewer?.isCustomer ?? false;
    final authorAsync = ref.watch(postProfileProvider(post.authorId));
    final providerId = _providerIdFor(post, authorAsync.value);
    final provider = providerId == null
        ? null
        : providerId == post.authorId
            ? authorAsync.value
            : ref.watch(postProfileProvider(providerId)).value;
    final serviceId = post.serviceId;
    final service = serviceId == null ? null : ref.watch(serviceByIdProvider(serviceId)).value;
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: topInset + _barHeight)),
              SliverToBoxAdapter(child: _MediaCarousel(post: post)),
              SliverToBoxAdapter(child: _EngagementRow(post: post)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                sliver: SliverList.list(
                  children: [
                    if (post.reviewId != null) ...[
                      const _VerifiedReviewTag(),
                      const SizedBox(height: 10),
                    ],
                    if ((post.caption?.trim() ?? '').isNotEmpty)
                      _ExpandableCaption(
                        author: authorAsync.value == null ? null : postAuthorName(authorAsync.value!),
                        text: post.caption!.trim(),
                      ),
                    _CommentsLink(post: post),
                    if (serviceId != null) ...[
                      const SizedBox(height: 16),
                      _TaggedServicePill(
                        serviceId: serviceId,
                        onTap: (service) => isClient
                            ? showServiceBookingSheet(context, service: service, excludePostId: post.id)
                            : showServiceDetailsSheet(context, service: service, excludePostId: post.id),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopBar(
              height: _barHeight,
              author: authorAsync,
              onBack: onBack,
              onMore: deleting ? null : () => _showPostActions(context, ref, isOwner: isOwner),
            ),
          ),
        ],
      ),
      // Booking is client-only; providers (including the owner) never see it.
      bottomNavigationBar: isClient && provider != null
          ? _ProviderQuickCard(
              provider: provider,
              service: service,
              onOpenProfile: () => context.pushNamed(
                AppRoute.publicProviderProfile.name,
                pathParameters: {'id': provider.id},
              ),
              onPrimary: () => service != null
                  ? showServiceBookingSheet(context, service: service, excludePostId: post.id)
                  : showProviderContactSheet(context, provider),
            )
          : null,
    );
  }

  Future<void> _showPostActions(BuildContext context, WidgetRef ref, {required bool isOwner}) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        void comingSoon(String feature) {
          Navigator.of(sheetContext).pop();
          context.showComingSoon(feature);
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionTile(
                  icon: Icons.ios_share_rounded,
                  label: 'Share',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    sharePost(context, ref, post);
                  },
                ),
                if (isOwner)
                  _ActionTile(icon: Icons.edit_outlined, label: 'Edit caption', onTap: () => comingSoon('Editing posts'))
                else
                  _ActionTile(
                    icon: Icons.flag_outlined,
                    label: 'Report post',
                    onTap: () => comingSoon('Reporting posts'),
                  ),
                if (isOwner)
                  _ActionTile(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete post',
                    destructive: true,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _confirmDelete(context, ref);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text("It will be removed from your profile and the feed. This can't be undone."),
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
    if (confirmed != true || !context.mounted) return;

    final success = await ref.read(deletePostControllerProvider.notifier).deletePost(
          postId: post.id,
          mediaUrls: post.mediaUrls,
          authorId: post.authorId,
        );
    if (!context.mounted) return;
    if (success) {
      context.showAppSnackBar('Post deleted');
      Navigator.of(context).pop();
    } else {
      context.showAppSnackBar("Couldn't delete the post. Please try again.", isError: true);
    }
  }
}

/// Translucent, blurred bar pinned over the content.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.height, required this.author, required this.onMore, this.onBack});

  final double height;
  final AsyncValue<ProfileModel?> author;
  final VoidCallback? onBack;
  /// Null while the post is being deleted.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.78),
            border: Border(bottom: BorderSide(color: scheme.onSurface.withValues(alpha: 0.06))),
          ),
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
          height: height + MediaQuery.paddingOf(context).top,
          child: Row(
            children: [
              const SizedBox(width: 4),
              BackButton(onPressed: onBack),
              Expanded(
                child: switch (author) {
                  AsyncData(:final value?) => Row(
                      children: [
                        PostAuthorAvatar(profile: value, radius: 16),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            postAuthorName(value),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: scheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                  AsyncLoading() => const Shimmer(
                      child: Row(
                        children: [
                          SkeletonBox.circle(size: 32),
                          SizedBox(width: 10),
                          SkeletonBox(width: 120, height: 14, borderRadius: 6),
                        ],
                      ),
                    ),
                  _ => Text('Post', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurface)),
                },
              ),
              IconButton(tooltip: 'More options', icon: const Icon(Icons.more_horiz_rounded), onPressed: onMore),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// 4:5 swipeable media with dot indicators. Double-tap likes; tap opens a
/// full-screen pinch-to-zoom viewer.
class _MediaCarousel extends ConsumerStatefulWidget {
  const _MediaCarousel({required this.post});

  final PostModel post;

  @override
  ConsumerState<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends ConsumerState<_MediaCarousel> {
  int _page = 0;
  int _burst = 0;

  Future<void> _onDoubleTap() async {
    if (ref.read(userProfileProvider).value == null) return;
    HapticFeedback.lightImpact();
    setState(() => _burst++);
    // Double-tap only ever likes.
    final ok = await ref.read(postEngagementStoreProvider.notifier).setLiked(widget.post, true);
    if (!ok && mounted) context.showAppSnackBar("Couldn't save your like. Please try again.", isError: true);
  }

  void _openViewer() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => _MediaViewer(urls: widget.post.mediaUrls, initialPage: _page),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.post.mediaUrls;
    final scheme = context.colorScheme;

    if (urls.isEmpty) {
      return AspectRatio(
        aspectRatio: 4 / 5,
        child: ColoredBox(
          color: scheme.onSurface.withValues(alpha: 0.05),
          child: Icon(Icons.image_not_supported_outlined, size: 48, color: scheme.onSurface.withValues(alpha: 0.3)),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onDoubleTap: _onDoubleTap,
            onTap: _openViewer,
            child: PageView.builder(
              itemCount: urls.length,
              onPageChanged: (page) => setState(() => _page = page),
              itemBuilder: (context, index) => Semantics(
                image: true,
                label: 'Photo ${index + 1} of ${urls.length}',
                child: CachedNetworkImage(
                  imageUrl: urls[index],
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const Shimmer(child: SkeletonBox(borderRadius: 0)),
                  errorWidget: (_, _, _) => ColoredBox(
                    color: scheme.onSurface.withValues(alpha: 0.05),
                    child: Icon(Icons.broken_image_outlined, size: 40, color: scheme.onSurface.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(child: Center(child: HeartBurst(key: ValueKey(_burst), visible: _burst > 0))),
          if (urls.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 14,
              child: IgnorePointer(child: MediaDots(count: urls.length, index: _page)),
            ),
        ],
      ),
    );
  }
}

/// Full-screen viewer. Paging is disabled while zoomed so a pan moves the
/// photo instead of switching to the next one.
class _MediaViewer extends StatefulWidget {
  const _MediaViewer({required this.urls, required this.initialPage});

  final List<String> urls;
  final int initialPage;

  @override
  State<_MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<_MediaViewer> {
  late final PageController _pageController = PageController(initialPage: widget.initialPage);
  late final List<TransformationController> _transforms =
      List.generate(widget.urls.length, (_) => TransformationController());
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    for (final controller in _transforms) {
      controller.addListener(() {
        final zoomed = controller.value.getMaxScaleOnAxis() > 1.01;
        if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _transforms) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
            itemCount: widget.urls.length,
            onPageChanged: (_) {
              for (final controller in _transforms) {
                controller.value = Matrix4.identity();
              }
            },
            itemBuilder: (context, index) => InteractiveViewer(
              transformationController: _transforms[index],
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.urls[index],
                  fit: BoxFit.contain,
                  placeholder: (_, _) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                  errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.15)),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shares [post]'s public link through the system share sheet.
Future<void> sharePost(BuildContext context, WidgetRef ref, PostModel post) {
  final caption = post.caption?.trim() ?? '';
  return shareLink(
    context,
    ref,
    text: caption.isEmpty
        ? 'Check out this look on Myglo'
        : 'Check out this look on Myglo: ${caption.length > 80 ? '${caption.substring(0, 79)}…' : caption}',
    url: ShareLinks.post(post.id),
    subject: 'A look on Myglo',
  );
}

/// Like, comment and share, with live counts. Opening the post loads its
/// current counts and the viewer's like in one request; taps update at once.
class _EngagementRow extends ConsumerStatefulWidget {
  const _EngagementRow({required this.post});

  final PostModel post;

  @override
  ConsumerState<_EngagementRow> createState() => _EngagementRowState();
}

class _EngagementRowState extends ConsumerState<_EngagementRow> {
  PostModel get post => widget.post;

  @override
  void initState() {
    super.initState();
    // After the first frame: providers can't be changed while building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(postEngagementStoreProvider.notifier).refresh(post.id);
    });
  }

  Future<void> _toggle(bool liked) async {
    HapticFeedback.selectionClick();
    final ok = await ref.read(postEngagementStoreProvider.notifier).setLiked(post, !liked);
    if (!ok && mounted) {
      context.showAppSnackBar("Couldn't save your like. Please try again.", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final engagement = PostEngagementView.of(post, ref.watch(postEngagementProvider(post.id)));
    final liked = engagement.liked ?? false;
    final canEngage = ref.watch(userProfileProvider.select((p) => p.value != null));
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final countStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: Row(
        children: [
          IconButton(
            tooltip: liked ? 'Unlike' : 'Like',
            onPressed: canEngage ? () => _toggle(liked) : null,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: Icon(
                liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey(liked),
                size: 28,
                color: liked ? AppTheme.destructive : scheme.onSurface,
              ),
            ),
          ),
          Semantics(
            label: '${engagement.likesCount} ${engagement.likesCount == 1 ? 'like' : 'likes'}',
            excludeSemantics: true,
            child: Text(Formatters.compactCount(engagement.likesCount), style: countStyle),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Comments',
            onPressed: () => showPostCommentsSheet(context, post: post),
            icon: Icon(Icons.chat_bubble_outline_rounded, size: 25, color: scheme.onSurface),
          ),
          Semantics(
            label: '${engagement.commentsCount} ${engagement.commentsCount == 1 ? 'comment' : 'comments'}',
            excludeSemantics: true,
            child: Text(Formatters.compactCount(engagement.commentsCount), style: countStyle),
          ),
          const SizedBox(width: 4),
          Builder(
            builder: (buttonContext) => IconButton(
              tooltip: 'Share',
              onPressed: () => sharePost(buttonContext, ref, post),
              icon: Icon(Icons.ios_share_rounded, size: 24, color: scheme.onSurface),
            ),
          ),
          const Spacer(),
          Text(Formatters.relativeTime(post.createdAt), style: TextStyle(fontSize: 13, color: muted)),
          IconButton(
            tooltip: 'Save',
            onPressed: () => context.showComingSoon('Saving posts'),
            icon: Icon(Icons.bookmark_border_rounded, size: 26, color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}

/// "View all 12 comments" under the caption, once there are any.
class _CommentsLink extends ConsumerWidget {
  const _CommentsLink({required this.post});

  final PostModel post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = PostEngagementView.of(post, ref.watch(postEngagementProvider(post.id))).commentsCount;
    if (count == 0) return const SizedBox.shrink();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: () => showPostCommentsSheet(context, post: post),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 40),
          foregroundColor: context.colorScheme.onSurface.withValues(alpha: 0.55),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        child: Text(count == 1 ? 'View 1 comment' : 'View all ${Formatters.compactCount(count)} comments'),
      ),
    );
  }
}

/// Marks a post that holds a review's photos.
class _VerifiedReviewTag extends StatelessWidget {
  const _VerifiedReviewTag();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: scheme.secondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, size: 15, color: scheme.secondary),
            const SizedBox(width: 5),
            Text(
              'From a verified review',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: scheme.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Caption trimmed to [_collapsedLines] with an inline "more"/"less" toggle.
/// Hashtags and @mentions are emphasised.
class _ExpandableCaption extends StatefulWidget {
  const _ExpandableCaption({required this.author, required this.text});

  final String? author;
  final String text;

  @override
  State<_ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<_ExpandableCaption> {
  static const int _collapsedLines = 3;
  static final RegExp _tag = RegExp(r'[#@][\w.]+');

  bool _expanded = false;

  List<InlineSpan> _spans(String text, TextStyle base, TextStyle tag) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in _tag.allMatches(text)) {
      if (match.start > last) spans.add(TextSpan(text: text.substring(last, match.start), style: base));
      spans.add(TextSpan(text: match.group(0), style: tag));
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last), style: base));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final base = TextStyle(fontSize: 14.5, height: 1.5, color: scheme.onSurface.withValues(alpha: 0.85));
    final tag = base.copyWith(fontWeight: FontWeight.w700, color: scheme.secondary);
    final authorStyle = base.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface);
    final toggleStyle = base.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface.withValues(alpha: 0.5));
    final prefix = widget.author == null ? <InlineSpan>[] : [TextSpan(text: '${widget.author}  ', style: authorStyle)];

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        bool fits(String text, {String suffix = ''}) {
          final painter = TextPainter(
            text: TextSpan(children: [
              ...prefix,
              ..._spans(text, base, tag),
              if (suffix.isNotEmpty) TextSpan(text: suffix, style: toggleStyle),
            ]),
            textDirection: Directionality.of(context),
            textScaler: textScaler,
            maxLines: _collapsedLines,
          )..layout(maxWidth: constraints.maxWidth);
          final overflow = painter.didExceedMaxLines;
          painter.dispose();
          return !overflow;
        }

        final full = widget.text;
        final needsToggle = !fits(full);
        if (!needsToggle) return Text.rich(TextSpan(children: [...prefix, ..._spans(full, base, tag)]));

        const more = '… more';
        String visible = full;
        if (!_expanded) {
          // Longest prefix that still fits alongside "… more".
          var low = 0;
          var high = full.length;
          while (low < high) {
            final mid = (low + high + 1) ~/ 2;
            if (fits(full.substring(0, mid).trimRight(), suffix: more)) {
              low = mid;
            } else {
              high = mid - 1;
            }
          }
          visible = full.substring(0, low).trimRight();
        }

        return Semantics(
          button: true,
          hint: _expanded ? 'Show less' : 'Show full caption',
          child: GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text.rich(
              TextSpan(children: [
                ...prefix,
                ..._spans(visible, base, tag),
                TextSpan(text: _expanded ? '  less' : more, style: toggleStyle),
              ]),
            ),
          ),
        );
      },
    );
  }
}

/// "Tagged service" shortcut beneath the caption.
class _TaggedServicePill extends ConsumerWidget {
  const _TaggedServicePill({required this.serviceId, required this.onTap});

  final String serviceId;
  final ValueChanged<ServiceModel> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final serviceAsync = ref.watch(serviceByIdProvider(serviceId));

    return switch (serviceAsync) {
      AsyncData(:final value?) => Material(
          color: scheme.primary.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: scheme.primary.withValues(alpha: 0.3)),
          ),
          child: InkWell(
            onTap: () => onTap(value),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
                    child: Icon(Icons.content_cut_rounded, size: 16, color: scheme.secondary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TAGGED SERVICE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${value.name} — ${Formatters.aud(value.price)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: scheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 20, color: scheme.onSurface.withValues(alpha: 0.6)),
                ],
              ),
            ),
          ),
        ),
      AsyncLoading() => const Shimmer(child: SkeletonBox(height: 58, borderRadius: 14)),
      // Deleted service, or a failure (already reported): just leave it out.
      _ => const SizedBox.shrink(),
    };
  }
}

/// Fixed bottom bar for clients: who did the work and how to book it.
class _ProviderQuickCard extends StatelessWidget {
  const _ProviderQuickCard({
    required this.provider,
    required this.service,
    required this.onOpenProfile,
    required this.onPrimary,
  });

  final ProfileModel provider;
  final ServiceModel? service;
  final VoidCallback onOpenProfile;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08))),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpenProfile,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    PostAuthorAvatar(profile: provider, radius: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            postAuthorName(provider),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: scheme.onSurface),
                          ),
                          const SizedBox(height: 2),
                          ProviderRatingLine(
                            providerId: provider.id,
                            iconSize: 14,
                            style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: Text(service != null ? 'Book this look' : 'Inquire'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.destructive = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppTheme.destructive : context.colorScheme.onSurface;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: color)),
      onTap: onTap,
    );
  }
}
