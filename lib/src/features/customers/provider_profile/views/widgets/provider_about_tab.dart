import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../shared/authentication/models/profile_model.dart';
import 'section_states.dart';

const TextStyle _headingStyle = TextStyle(fontSize: 17, fontWeight: FontWeight.w800);
const TextStyle _bodyStyle = TextStyle(fontSize: 15, height: 1.45);

/// About / details tab of the public provider profile, as slivers.
///
/// Opening hours, cancellation policy and reviews are not stored for
/// providers yet, so those sections explain that instead of staying blank.
class ProviderAboutTab extends StatelessWidget {
  const ProviderAboutTab({
    super.key,
    required this.profile,
    required this.onRetry,
    this.distanceKm,
  });

  final AsyncValue<ProfileModel?> profile;
  final VoidCallback onRetry;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    return switch (profile) {
      AsyncData(:final value?) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        sliver: SliverList.list(children: _sections(context, value)),
      ),
      AsyncError(:final error) => SliverToBoxAdapter(
        child: SectionErrorView(
          title: "Details didn't load",
          message: describeLoadError(error, subject: "this provider's details"),
          onRetry: onRetry,
        ),
      ),
      // A missing provider is handled by the screen; anything else is loading.
      _ => const SliverToBoxAdapter(child: _AboutSkeleton()),
    };
  }

  List<Widget> _sections(BuildContext context, ProfileModel profile) {
    final muted = context.colorScheme.onSurface.withValues(alpha: 0.6);
    final bio = profile.bio?.trim() ?? '';
    final address = profile.addressText?.trim() ?? '';
    final distance = distanceKm;

    return [
      _Section(
        title: 'About',
        child: Text(
          bio.isNotEmpty ? bio : "This provider hasn't added a bio yet.",
          style: _bodyStyle.copyWith(
            color: bio.isNotEmpty ? context.colorScheme.onSurface.withValues(alpha: 0.85) : muted,
          ),
        ),
      ),
      _Section(
        title: 'Location',
        child: _InfoCard(
          icon: Icons.location_on_outlined,
          title: address.isNotEmpty ? address : 'Address not provided',
          subtitle: distance == null ? null : '${Formatters.distanceKm(distance)} away',
        ),
      ),
      const _Section(
        title: 'Opening hours',
        child: _InfoCard(
          icon: Icons.schedule_outlined,
          title: 'Hours not listed yet',
          subtitle: 'Contact the provider to check their availability.',
        ),
      ),
      const _Section(
        title: 'Cancellation policy',
        child: _InfoCard(
          icon: Icons.event_busy_outlined,
          title: 'No policy published',
          subtitle: 'Confirm cancellation terms with the provider before you book.',
        ),
      ),
      const _Section(
        title: 'Reviews',
        child: SectionEmptyView(
          icon: Icons.rate_review_outlined,
          title: 'No reviews yet',
          message: 'Reviews from clients will appear here after their appointments.',
        ),
      ),
    ];
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: _headingStyle.copyWith(color: context.colorScheme.onSurface)),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: context.colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutSkeleton extends StatelessWidget {
  const _AboutSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 28, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SkeletonText(style: _headingStyle, widthFactor: 0.3),
            SizedBox(height: 10),
            SkeletonText(style: _bodyStyle),
            SkeletonText(style: _bodyStyle),
            SkeletonText(style: _bodyStyle, widthFactor: 0.6),
            SizedBox(height: 20),
            SkeletonText(style: _headingStyle, widthFactor: 0.35),
            SizedBox(height: 10),
            SkeletonBox(height: 72, borderRadius: 16),
            SizedBox(height: 20),
            SkeletonText(style: _headingStyle, widthFactor: 0.3),
            SizedBox(height: 10),
            ReviewCardSkeleton(),
          ],
        ),
      ),
    );
  }
}
