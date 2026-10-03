import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../controllers/discovery_feed_controller.dart';
import '../post_detail_screen.dart';
import 'post_widgets.dart';

/// How much detail a [DiscoverTile] has room for.
enum DiscoverTileSize {
  /// Small square: avatar and likes only, icon-only badges.
  compact,

  /// Grid cell or wide/tall bento tile: author name and likes.
  regular,

  /// Large bento tile: adds a line of caption.
  hero,
}

/// Corner radius shared by tiles and their skeletons.
const double discoverTileRadius = 20;

/// One look as a photo tile: the cover image with the author, likes, and
/// badges for carousels and bookable services laid over it. Tapping opens the
/// post.
class DiscoverTile extends StatelessWidget {
  const DiscoverTile({super.key, required this.entry, this.size = DiscoverTileSize.regular});

  final FeedEntry entry;
  final DiscoverTileSize size;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final post = entry.post;
    final author = entry.author;
    final authorName = author == null ? postAuthorFallbackName : postAuthorName(author);
    final imageUrl = post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null;
    final caption = post.caption?.trim() ?? '';
    final compact = size == DiscoverTileSize.compact;
    final hero = size == DiscoverTileSize.hero;
    final fallback = ColoredBox(
      color: scheme.onSurface.withValues(alpha: 0.05),
      child: Icon(Icons.image_not_supported_outlined, color: scheme.onSurface.withValues(alpha: 0.3)),
    );
    const textShadow = [Shadow(color: Colors.black38, blurRadius: 4)];
    final inset = compact ? 8.0 : 10.0;

    return Semantics(
      button: true,
      label: [
        'Post by $authorName',
        if (caption.isNotEmpty) caption,
        '${post.likesCount} ${post.likesCount == 1 ? 'like' : 'likes'}',
        if (post.mediaUrls.length > 1) '${post.mediaUrls.length} photos',
        if (post.serviceId != null) 'bookable service',
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: scheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(discoverTileRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => PostDetailScreen(post: post)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl == null)
                fallback
              else
                LayoutBuilder(
                  builder: (context, constraints) => CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 220),
                    // Decode at the tile's size instead of full resolution.
                    memCacheWidth: constraints.maxWidth.isFinite
                        ? (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context)).round()
                        : null,
                    placeholder: (_, _) => const Shimmer(child: SkeletonBox(borderRadius: 0)),
                    errorWidget: (_, _, _) => fallback,
                  ),
                ),
              // Scrim so white text reads on any photo.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: hero ? 140 : 96,
                child: const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x99000000)],
                      ),
                    ),
                  ),
                ),
              ),
              if (post.serviceId != null)
                Positioned(
                  top: inset,
                  left: inset,
                  child: _GlassChip(icon: Icons.event_available_rounded, label: compact ? null : 'Bookable'),
                ),
              if (post.mediaUrls.length > 1)
                Positioned(
                  top: inset,
                  right: inset,
                  child: const Icon(
                    Icons.collections_rounded,
                    size: 18,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                  ),
                ),
              Positioned(
                left: inset,
                right: inset,
                bottom: inset,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hero && caption.isNotEmpty) ...[
                      Text(
                        caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          shadows: textShadow,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: PostAuthorAvatar(profile: author, radius: hero ? 13 : 11),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: compact
                              ? const SizedBox.shrink()
                              : Text(
                                  authorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: hero ? 13.5 : 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    shadows: textShadow,
                                  ),
                                ),
                        ),
                        if (post.likesCount > 0) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.favorite_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            Formatters.compactCount(post.likesCount),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              shadows: textShadow,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small frosted label laid over a photo. Icon-only when [label] is null.
class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.icon, this.label});

  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return Container(
      padding: label == null ? const EdgeInsets.all(5) : const EdgeInsets.fromLTRB(7, 4, 9, 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.colorScheme.secondary),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.colorScheme.onSurface),
            ),
          ],
        ],
      ),
    );
  }
}
