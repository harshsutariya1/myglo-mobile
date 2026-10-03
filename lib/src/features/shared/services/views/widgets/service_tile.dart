import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../providers/provider_profiles/models/service_model.dart';

/// Geometry shared by [ServiceTile] and `ServiceRowSkeleton`.
abstract final class ServiceTileMetrics {
  static const double thumb = 72;
  static const double thumbRadius = 10;
  static const double cardRadius = 16;
  static const double cardPadding = 12;
  static const double actionSize = 40;
  static const EdgeInsets margin = EdgeInsets.symmetric(horizontal: 20, vertical: 6);

  static const TextStyle categoryStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.8,
    height: 1.2,
  );
  static const TextStyle titleStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3);
  static const TextStyle metaStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.2);
  static const TextStyle priceStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.2);
}

/// One service in a list: thumbnail, category, name, duration and price, with
/// a [trailing] action whose shape depends on who is looking (an add button
/// for clients, an owner menu for the provider).
class ServiceTile extends StatelessWidget {
  const ServiceTile({
    super.key,
    required this.service,
    this.onTap,
    this.trailing,
    this.margin = ServiceTileMetrics.margin,
  });

  final ServiceModel service;
  final VoidCallback? onTap;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final category = service.category?.trim() ?? '';

    return Padding(
      padding: margin,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ServiceTileMetrics.cardRadius),
          side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(ServiceTileMetrics.cardPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ServiceThumbnail(
                  imageUrl: service.imageUrl,
                  size: ServiceTileMetrics.thumb,
                  radius: ServiceTileMetrics.thumbRadius,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (category.isNotEmpty) ...[
                        Text(
                          category.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ServiceTileMetrics.categoryStyle.copyWith(color: scheme.secondary),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        service.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ServiceTileMetrics.titleStyle.copyWith(color: scheme.onSurface),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 15, color: muted),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              Formatters.duration(service.durationMinutes),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ServiceTileMetrics.metaStyle.copyWith(color: muted),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            Formatters.aud(service.price),
                            style: ServiceTileMetrics.priceStyle.copyWith(color: scheme.onSurface),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 4),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded service photo with a branded fallback when there is none (or it
/// fails to load).
class ServiceThumbnail extends StatelessWidget {
  const ServiceThumbnail({super.key, required this.imageUrl, required this.size, required this.radius});

  final String? imageUrl;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.16),
            scheme.tertiary.withValues(alpha: 0.32),
          ],
        ),
      ),
      child: Icon(Icons.spa_outlined, color: scheme.secondary, size: size * 0.36),
    );
    final url = imageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null || url.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, _) => Shimmer(child: SkeletonBox(width: size, height: size, borderRadius: 0)),
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }
}

/// Client-side "+" action on a [ServiceTile].
class ServiceAddButton extends StatelessWidget {
  const ServiceAddButton({super.key, required this.serviceName, required this.onPressed});

  final String serviceName;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SizedBox.square(
      dimension: ServiceTileMetrics.actionSize,
      child: IconButton.filledTonal(
        tooltip: 'Book $serviceName',
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: scheme.primary.withValues(alpha: 0.14),
          foregroundColor: scheme.onSurface,
        ),
        icon: const Icon(Icons.add_rounded, size: 22),
      ),
    );
  }
}
