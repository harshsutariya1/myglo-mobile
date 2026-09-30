import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../discovery_feed/controllers/user_posts_controller.dart';
import '../../../../discovery_feed/models/post_model.dart';
import '../../../../discovery_feed/views/post_detail_screen.dart';
import 'section_states.dart';

/// Grid geometry shared by the posts grid and its skeleton.
abstract final class _PostGrid {
  static const int columns = 2;
  static const double spacing = 12;
  static const EdgeInsets padding = EdgeInsets.fromLTRB(24, 16, 24, 0);

  // The caption and timestamp sit in fixed-height slots so every tile, with or
  // without a caption, has the same height as the skeleton tile.
  static const double captionGap = 8;
  static const double captionHeight = 18;
  static const double timeGap = 2;
  static const double timeHeight = 16;
  static const double textBlock = captionGap + captionHeight + timeGap + timeHeight;

  static const TextStyle captionStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
  static const TextStyle timeStyle = TextStyle(fontSize: 12);

  /// [crossAxisExtent] is the width inside [padding].
  static SliverGridDelegate delegate(double crossAxisExtent) {
    final tileWidth = (crossAxisExtent - spacing * (columns - 1)) / columns;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing + 4,
      mainAxisExtent: tileWidth + textBlock,
    );
  }
}

/// Posts / portfolio tab of the public provider profile, as slivers.
///
/// Row-level security already limits other users to approved posts.
class ProviderPostsTab extends ConsumerWidget {
  const ProviderPostsTab({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(userPostsProvider(providerId));

    return postsAsync.when(
      loading: () => SliverPadding(
        padding: _PostGrid.padding,
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) => SliverGrid.builder(
            gridDelegate: _PostGrid.delegate(constraints.crossAxisExtent),
            itemCount: 4,
            itemBuilder: (_, _) => const Shimmer(child: _PostTileSkeleton()),
          ),
        ),
      ),
      error: (error, _) => SliverToBoxAdapter(
        child: SectionErrorView(
          title: "Posts didn't load",
          message: describeLoadError(error, subject: 'these posts'),
          onRetry: () => ref.invalidate(userPostsProvider(providerId)),
        ),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return const SliverToBoxAdapter(
            child: SectionEmptyView(
              icon: Icons.photo_library_outlined,
              title: 'No posts yet',
              message: "This provider hasn't shared any work yet.",
            ),
          );
        }
        return SliverPadding(
          padding: _PostGrid.padding,
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) => SliverGrid.builder(
              gridDelegate: _PostGrid.delegate(constraints.crossAxisExtent),
              itemCount: posts.length,
              itemBuilder: (context, index) => _PostTile(post: posts[index]),
            ),
          ),
        );
      },
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post});

  final PostModel post;

  @override
  Widget build(BuildContext context) {
    final imageUrl = post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null;
    final caption = post.caption?.trim() ?? '';
    final muted = context.colorScheme.onSurface.withValues(alpha: 0.55);
    final brokenImage = Container(
      color: context.colorScheme.onSurface.withValues(alpha: 0.06),
      alignment: Alignment.center,
      child: Icon(Icons.image_not_supported_outlined, color: muted),
    );

    return Semantics(
      button: true,
      label: caption.isNotEmpty ? 'Post: $caption' : 'Post',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl == null)
                      brokenImage
                    else
                      CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => const Shimmer(child: SkeletonBox(borderRadius: 0)),
                        errorWidget: (_, _, _) => brokenImage,
                      ),
                    if (post.mediaUrls.length > 1)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: Icon(
                          Icons.filter_none,
                          color: Colors.white,
                          size: 16,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: _PostGrid.captionGap),
            SizedBox(
              height: _PostGrid.captionHeight,
              child: Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _PostGrid.captionStyle.copyWith(color: context.colorScheme.onSurface),
              ),
            ),
            const SizedBox(height: _PostGrid.timeGap),
            SizedBox(
              height: _PostGrid.timeHeight,
              child: Text(
                Formatters.relativeTime(post.createdAt),
                maxLines: 1,
                style: _PostGrid.timeStyle.copyWith(color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostTileSkeleton extends StatelessWidget {
  const _PostTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(aspectRatio: 1, child: SkeletonBox(borderRadius: 16)),
        SizedBox(height: _PostGrid.captionGap),
        SizedBox(
          height: _PostGrid.captionHeight,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(widthFactor: 0.75, child: SkeletonBox(height: 11, borderRadius: 4)),
          ),
        ),
        SizedBox(height: _PostGrid.timeGap),
        SizedBox(
          height: _PostGrid.timeHeight,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(widthFactor: 0.35, child: SkeletonBox(height: 10, borderRadius: 4)),
          ),
        ),
      ],
    );
  }
}
