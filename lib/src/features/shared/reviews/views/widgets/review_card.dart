import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../discovery_feed/views/shared_post_screen.dart';
import '../../../bookings/views/widgets/booking_card.dart' show PersonAvatar;
import '../../models/review.dart';
import 'star_rating.dart';

/// One review: who wrote it, the stars, when, which services, the text and
/// photos, and the provider's reply.
class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    this.providerName,
    this.showServices = true,
    this.onReply,
    this.title,
  });

  final Review review;

  /// Shown above the reply ("Response from …").
  final String? providerName;

  /// Lists the reviewed services (hidden where they're obvious, e.g. on a
  /// service's own page).
  final bool showServices;

  /// The provider's own view: adds "Reply" / "Edit reply".
  final VoidCallback? onReply;

  /// Replaces the reviewer's name (e.g. "Your review").
  final String? title;

  void _openPhotos(BuildContext context) {
    final postId = review.postId;
    if (postId == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SharedPostScreen(postId: postId)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final when = Formatters.relativeTime(review.createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            PersonAvatar(name: review.reviewerName, url: review.reviewerAvatarUrl, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? review.reviewerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      StarRating(rating: review.rating.toDouble(), size: 15),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          review.isEdited ? '$when · Edited' : when,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Tooltip(
              message: 'From a completed Myglo booking',
              child: Icon(Icons.verified_rounded, size: 18, color: scheme.secondary.withValues(alpha: 0.8)),
            ),
          ],
        ),
        if (showServices && review.serviceNames.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            review.serviceNames.join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: scheme.secondary),
          ),
        ],
        if (review.body case final body?) ...[
          const SizedBox(height: 8),
          _ExpandableText(text: body),
        ],
        if (review.photoUrls.isNotEmpty) ...[
          const SizedBox(height: 10),
          _PhotoStrip(urls: review.photoUrls, onTap: review.postId == null ? null : () => _openPhotos(context)),
        ],
        if (review.hasReply) ...[
          const SizedBox(height: 12),
          _ReplyBlock(review: review, providerName: providerName, onEdit: onReply),
        ] else if (onReply != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onReply,
              icon: const Icon(Icons.reply_rounded, size: 18),
              label: const Text('Reply publicly'),
              style: TextButton.styleFrom(
                foregroundColor: scheme.secondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReplyBlock extends StatelessWidget {
  const _ReplyBlock({required this.review, required this.providerName, required this.onEdit});

  final Review review;
  final String? providerName;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final repliedAt = review.repliedAt;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    providerName == null ? 'Response from the provider' : 'Response from $providerName',
                    if (repliedAt != null) Formatters.relativeTime(repliedAt),
                  ].join(' · '),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: muted),
                ),
                const SizedBox(height: 4),
                _ExpandableText(text: review.reply!),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              tooltip: 'Edit reply',
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.edit_outlined, size: 18, color: muted),
            ),
        ],
      ),
    );
  }
}

/// Up to four square thumbnails; tapping opens the review's photo post.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.urls, required this.onTap});

  final List<String> urls;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Semantics(
      button: onTap != null,
      label: '${urls.length} ${urls.length == 1 ? 'photo' : 'photos'} from this review',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            for (final url in urls) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox.square(
                  dimension: 72,
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    memCacheWidth: 216,
                    placeholder: (_, _) => const Shimmer(child: SkeletonBox(borderRadius: 0)),
                    errorWidget: (_, _, _) => ColoredBox(
                      color: scheme.onSurface.withValues(alpha: 0.06),
                      child: Icon(Icons.broken_image_outlined, color: scheme.onSurface.withValues(alpha: 0.3)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// Text clipped to a few lines with a "more" / "less" toggle.
class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});

  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  static const int _collapsedLines = 4;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final style = TextStyle(fontSize: 14.5, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.85));
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: _collapsedLines,
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        final text = Text(
          widget.text,
          style: style,
          maxLines: _expanded ? null : _collapsedLines,
          overflow: _expanded ? null : TextOverflow.ellipsis,
        );
        if (!overflows) return text;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            text,
            Semantics(
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(
                    _expanded ? 'Show less' : 'Read more',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: scheme.secondary),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// [ReviewCardSkeleton]s for a list that's loading.
class ReviewListSkeleton extends StatelessWidget {
  const ReviewListSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: [for (var i = 0; i < count; i++) const ReviewCardSkeleton()],
      ),
    );
  }
}
