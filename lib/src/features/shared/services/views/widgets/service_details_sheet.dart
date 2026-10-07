import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../discovery_feed/controllers/service_posts_controller.dart';
import '../../../../discovery_feed/models/post_model.dart';
import '../../../../discovery_feed/views/post_detail_screen.dart';
import '../../../../providers/provider_profiles/models/service_catalog.dart';
import '../../../../providers/provider_profiles/models/service_model.dart';
import 'service_tile.dart';

/// Opens the details sheet for [service] on top of the current screen. It
/// opens at about two-thirds height and can be dragged up to nearly full.
///
/// Pass [onBook] to show the sticky booking bar. Leave it null for viewers who
/// can't book (the owning provider previewing their own service, or another
/// provider). [excludePostId] leaves one post out of the "Recent work" strip,
/// e.g. the post the sheet was opened from.
Future<void> showServiceDetailsSheet(
  BuildContext context, {
  required ServiceModel service,
  VoidCallback? onBook,
  String bookLabel = 'Book now',
  String? excludePostId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _ServiceDetailsSheet(
      service: service,
      bookLabel: bookLabel,
      excludePostId: excludePostId,
      onBook: onBook == null
          ? null
          : () {
              Navigator.of(sheetContext).pop();
              onBook();
            },
    ),
  );
}

abstract final class _Metrics {
  static const double initialSize = 0.68;
  static const double maxSize = 0.92;
  static const double radius = 28;
  static const double gutter = 20;
  static const double sectionGap = 28;
}

class _ServiceDetailsSheet extends StatelessWidget {
  const _ServiceDetailsSheet({
    required this.service,
    required this.bookLabel,
    required this.excludePostId,
    required this.onBook,
  });

  final ServiceModel service;
  final String bookLabel;
  final String? excludePostId;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final details = ServiceDescription.parse(service.description);
    final imageUrl = service.imageUrl?.trim() ?? '';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: _Metrics.initialSize,
      minChildSize: 0.35,
      maxChildSize: _Metrics.maxSize,
      snap: true,
      snapSizes: const [_Metrics.initialSize],
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(_Metrics.radius)),
          child: ColoredBox(
            color: scheme.surface,
            child: Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      // Part of the scrollable, so dragging the handle moves the sheet.
                      const SliverPersistentHeader(pinned: true, delegate: _HandleHeader()),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(_Metrics.gutter, 4, _Metrics.gutter, 0),
                        sliver: SliverList.list(
                          children: [
                            if (imageUrl.isNotEmpty) ...[
                              _HeroImage(url: imageUrl),
                              const SizedBox(height: 20),
                            ],
                            _TitleBlock(service: service),
                            const SizedBox(height: 18),
                            _FactsRow(service: service),
                            if (details.included.isNotEmpty) ...[
                              const SizedBox(height: _Metrics.sectionGap),
                              const _SectionTitle("What's included"),
                              const SizedBox(height: 12),
                              _IncludedCard(items: details.included),
                            ],
                            if (details.summary.isNotEmpty) ...[
                              const SizedBox(height: _Metrics.sectionGap),
                              const _SectionTitle('About this service'),
                              const SizedBox(height: 10),
                              Text(
                                details.summary,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.55,
                                  color: scheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _RecentWork(serviceId: service.id, excludePostId: excludePostId),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                    ],
                  ),
                ),
                if (onBook != null) _BookingBar(service: service, label: bookLabel, onBook: onBook!),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HandleHeader extends SliverPersistentHeaderDelegate {
  const _HandleHeader();

  static const double _height = 24;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final scheme = context.colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_HandleHeader oldDelegate) => false;
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, _) => const Shimmer(child: SkeletonBox(borderRadius: 0)),
          // A broken photo shouldn't leave a large empty frame at the top.
          errorWidget: (_, _, _) => LayoutBuilder(
            builder: (context, constraints) => ServiceThumbnail(
              imageUrl: null,
              size: constraints.maxWidth,
              radius: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.service});

  final ServiceModel service;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final category = service.category?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (category.isNotEmpty) ...[
          Text(
            category.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: scheme.secondary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          service.name,
          style: TextStyle(
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Duration and price as two equal tiles.
class _FactsRow extends StatelessWidget {
  const _FactsRow({required this.service});

  final ServiceModel service;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _FactTile(
              icon: Icons.schedule_rounded,
              label: 'Duration',
              value: Formatters.duration(service.durationMinutes),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _FactTile(
              icon: Icons.sell_outlined,
              label: 'Price',
              value: Formatters.aud(service.price),
            ),
          ),
        ],
      ),
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
            child: Icon(icon, size: 19, color: scheme.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: scheme.onSurface),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label, {this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Semantics(
      header: true,
      child: Text.rich(
        TextSpan(
          text: label,
          children: [
            if (trailing != null)
              TextSpan(
                text: '  $trailing',
                style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface.withValues(alpha: 0.4)),
              ),
          ],
        ),
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: scheme.onSurface),
      ),
    );
  }
}

class _IncludedCard extends StatelessWidget {
  const _IncludedCard({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: scheme.onSurface.withValues(alpha: 0.06)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_rounded, size: 14, color: scheme.secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      items[i],
                      style: TextStyle(fontSize: 15, height: 1.4, color: scheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Horizontal strip of approved posts tagged with the service. Renders
/// nothing until there is at least one to show; a failed load is already
/// reported by the repository and simply leaves the strip out.
class _RecentWork extends ConsumerWidget {
  const _RecentWork({required this.serviceId, required this.excludePostId});

  static const double _tile = 128;

  final String serviceId;
  final String? excludePostId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = [
      for (final post in ref.watch(servicePostsProvider(serviceId)).value ?? const <PostModel>[])
        if (post.id != excludePostId && post.mediaUrls.isNotEmpty) post,
    ];

    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: posts.isEmpty
          ? const SizedBox(width: double.infinity)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: _Metrics.sectionGap),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _Metrics.gutter),
                  child: _SectionTitle('Recent work', trailing: '${posts.length}'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: _tile,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: _Metrics.gutter),
                    itemCount: posts.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) => _WorkTile(post: posts[index], size: _tile),
                  ),
                ),
              ],
            ),
    );
  }
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({required this.post, required this.size});

  final PostModel post;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final caption = post.caption?.trim() ?? '';
    final radius = BorderRadius.circular(16);
    final broken = ColoredBox(
      color: scheme.onSurface.withValues(alpha: 0.06),
      child: Icon(Icons.image_not_supported_outlined, color: scheme.onSurface.withValues(alpha: 0.4)),
    );

    return Semantics(
      button: true,
      label: caption.isNotEmpty ? 'Post: $caption' : 'Post',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: post.mediaUrls.first,
                fit: BoxFit.cover,
                placeholder: (_, _) => const Shimmer(child: SkeletonBox(borderRadius: 0)),
                errorWidget: (_, _, _) => broken,
              ),
              if (post.mediaUrls.length > 1)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.filter_none,
                    color: Colors.white,
                    size: 15,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                  ),
                ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => PostDetailScreen(post: post)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingBar extends StatelessWidget {
  const _BookingBar({required this.service, required this.label, required this.onBook});

  final ServiceModel service;
  final String label;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(color: scheme.onSurface.withValues(alpha: 0.07), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(_Metrics.gutter, 14, _Metrics.gutter, 14 + MediaQuery.paddingOf(context).bottom),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Formatters.aud(service.price),
                  style: TextStyle(fontSize: 21, height: 1.15, fontWeight: FontWeight.w800, color: scheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.duration(service.durationMinutes),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: onBook,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.onSurface,
                    foregroundColor: scheme.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                  ),
                  child: Text(label),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
