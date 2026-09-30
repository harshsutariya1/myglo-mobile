import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../shared/authentication/models/profile_model.dart';

/// Layout constants shared by [ProviderProfileHeader] and its skeleton so both
/// occupy exactly the same space.
abstract final class ProviderHeaderMetrics {
  static const double avatarSize = 76;
  static const double ctaHeight = 48;
  static const EdgeInsets padding = EdgeInsets.fromLTRB(24, 20, 24, 8);
  static const TextStyle nameStyle = TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2);
  static const TextStyle metaStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);
  static const TextStyle addressStyle = TextStyle(fontSize: 14);
}

/// Business name used on the public profile, falling back to the owner's name.
String providerDisplayName(ProfileModel profile) {
  final business = profile.providerName?.trim() ?? '';
  if (business.isNotEmpty) return business;
  final owner = '${profile.firstName ?? ''} ${profile.lastName ?? ''}'.trim();
  return owner.isNotEmpty ? owner : 'Provider';
}

/// Identity block of the public provider profile: avatar, business name,
/// review summary, location and the primary actions.
class ProviderProfileHeader extends StatelessWidget {
  const ProviderProfileHeader({
    super.key,
    required this.profile,
    required this.onBookNow,
    required this.onContact,
    this.distanceKm,
  });

  final ProfileModel profile;
  final double? distanceKm;
  final VoidCallback onBookNow;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final name = providerDisplayName(profile);
    final address = profile.addressText?.trim() ?? '';
    final muted = context.colorScheme.onSurface.withValues(alpha: 0.6);

    return Padding(
      padding: ProviderHeaderMetrics.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Avatar(name: name, url: profile.profilePic),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ProviderHeaderMetrics.nameStyle.copyWith(
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Reviews are not collected yet, so every provider is new.
                    Row(
                      children: [
                        Icon(Icons.star_outline_rounded, size: 16, color: context.colorScheme.secondary),
                        const SizedBox(width: 4),
                        Text(
                          'New · No reviews yet',
                          style: ProviderHeaderMetrics.metaStyle.copyWith(color: muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 16, color: muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _locationLine(address),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ProviderHeaderMetrics.addressStyle.copyWith(color: muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: ProviderHeaderMetrics.ctaHeight,
                  child: FilledButton(
                    onPressed: onBookNow,
                    style: FilledButton.styleFrom(
                      backgroundColor: context.colorScheme.primary,
                      foregroundColor: context.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Book Now'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: ProviderHeaderMetrics.ctaHeight,
                  child: OutlinedButton.icon(
                    onPressed: onContact,
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Contact'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colorScheme.onSurface,
                      side: BorderSide(color: context.colorScheme.onSurface.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _locationLine(String address) {
    final place = address.isNotEmpty ? address : 'Location not provided';
    final distance = distanceKm;
    return distance == null ? place : '${Formatters.distanceKm(distance)} · $place';
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.url});

  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    const size = ProviderHeaderMetrics.avatarSize;
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final fallback = Container(
      color: context.colorScheme.primary,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: context.colorScheme.onPrimary,
        ),
      ),
    );

    return Semantics(
      label: '$name profile photo',
      image: true,
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: url == null
              ? fallback
              : CachedNetworkImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const Shimmer(child: SkeletonBox.circle(size: size)),
                  errorWidget: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}

/// Placeholder with the exact footprint of [ProviderProfileHeader].
class ProviderProfileHeaderSkeleton extends StatelessWidget {
  const ProviderProfileHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: Padding(
        padding: ProviderHeaderMetrics.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SkeletonBox.circle(size: ProviderHeaderMetrics.avatarSize),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonText(style: ProviderHeaderMetrics.nameStyle, widthFactor: 0.7),
                      SizedBox(height: 6),
                      SkeletonText(style: ProviderHeaderMetrics.metaStyle, widthFactor: 0.45),
                      SizedBox(height: 6),
                      SkeletonText(style: ProviderHeaderMetrics.addressStyle, widthFactor: 0.85),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: SkeletonBox(height: ProviderHeaderMetrics.ctaHeight, borderRadius: 14)),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(height: ProviderHeaderMetrics.ctaHeight, borderRadius: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
