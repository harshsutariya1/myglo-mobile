import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../discovery_feed/controllers/user_posts_controller.dart';
import '../../../../discovery_feed/models/post_model.dart';
import '../../../../discovery_feed/views/post_detail_screen.dart';
import 'section_states.dart';

/// Grid geometry shared by the portfolio grid and its skeleton: square
/// photo tiles, three across, with no text under them.
abstract final class _PostGrid {
  static const int columns = 3;
  static const double spacing = 4;
  static const double radius = 10;
  static const EdgeInsets padding = EdgeInsets.fromLTRB(24, 16, 24, 0);

  static const SliverGridDelegate delegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    crossAxisSpacing: spacing,
    mainAxisSpacing: spacing,
  );
}

/// Portfolio tab of the public provider profile: the provider's posts as a
/// photo grid, as slivers.
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
        sliver: SliverGrid.builder(
          gridDelegate: _PostGrid.delegate,
          itemCount: 9,
          itemBuilder: (_, _) => const Shimmer(child: SkeletonBox(borderRadius: _PostGrid.radius)),
        ),
      ),
      error: (error, _) => SliverToBoxAdapter(
        child: SectionErrorView(
          title: "Portfolio didn't load",
          message: describeLoadError(error, subject: 'this portfolio'),
          onRetry: () => ref.invalidate(userPostsProvider(providerId)),
        ),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return const SliverToBoxAdapter(
            child: SectionEmptyView(
              icon: Icons.photo_library_outlined,
              title: 'No portfolio yet',
              message: "This provider hasn't shared any work yet.",
            ),
          );
        }
        return SliverPadding(
          padding: _PostGrid.padding,
          sliver: SliverGrid.builder(
            gridDelegate: _PostGrid.delegate,
            itemCount: posts.length,
            itemBuilder: (context, index) => _PostTile(post: posts[index]),
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
      label: caption.isNotEmpty ? 'Portfolio photo: $caption' : 'Portfolio photo',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_PostGrid.radius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl == null)
                  brokenImage
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // A third of the screen: decode small to keep memory low.
                      final width = (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context)).round();
                      return CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: constraints.hasBoundedWidth && width > 0 ? width : null,
                        placeholder: (_, _) => const Shimmer(child: SkeletonBox(borderRadius: 0)),
                        errorWidget: (_, _, _) => brokenImage,
                      );
                    },
                  ),
                if (post.mediaUrls.length > 1)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(
                      Icons.filter_none,
                      color: Colors.white,
                      size: 14,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
