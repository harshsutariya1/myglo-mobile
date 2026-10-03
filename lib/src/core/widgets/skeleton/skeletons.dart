import 'package:flutter/material.dart';

import 'shimmer.dart';

export 'shimmer.dart';

/// Ready-made skeletons for the app's recurring surfaces.
///
/// Each one mirrors the geometry (fixed sizes, paddings and text line heights)
/// of the widget it stands in for, so nothing jumps when data arrives. None of
/// them animate by themselves: place them under a [Shimmer].

/// Mirrors `ProviderItemWithImage`: an 80×80 thumbnail beside three lines.
class ProviderItemSkeleton extends StatelessWidget {
  const ProviderItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SkeletonBox(width: 80, height: 80, borderRadius: 20),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonText(
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2),
                widthFactor: 0.3,
              ),
              SizedBox(height: 4),
              SkeletonText(
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                widthFactor: 0.6,
              ),
              SizedBox(height: 4),
              SkeletonText(style: TextStyle(fontSize: 14), widthFactor: 0.8),
            ],
          ),
        ),
      ],
    );
  }
}

/// A vertical list of [ProviderItemSkeleton]s with the Home list spacing.
class ProviderListSkeleton extends StatelessWidget {
  const ProviderListSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: [
          for (var i = 0; i < itemCount; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            const ProviderItemSkeleton(),
          ],
        ],
      ),
    );
  }
}

/// Mirrors the category heading used above grouped services.
class ServiceCategorySkeleton extends StatelessWidget {
  const ServiceCategorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: SkeletonText(
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        widthFactor: 0.4,
      ),
    );
  }
}

/// Mirrors `ServiceTile`: a bordered card with a 72×72 thumbnail, category,
/// name and a duration/price line.
///
/// Set [showAction] to reserve room for the trailing 40×40 action.
class ServiceRowSkeleton extends StatelessWidget {
  const ServiceRowSkeleton({super.key, this.showAction = false});

  final bool showAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x14000000)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(width: 72, height: 72, borderRadius: 10),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonText(
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, height: 1.2),
                    widthFactor: 0.3,
                  ),
                  SizedBox(height: 4),
                  SkeletonText(
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
                    widthFactor: 0.7,
                  ),
                  SizedBox(height: 8),
                  SkeletonText(
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.2),
                    widthFactor: 0.45,
                  ),
                ],
              ),
            ),
            if (showAction) ...[
              const SizedBox(width: 4),
              const SkeletonBox.circle(size: 40),
            ],
          ],
        ),
      ),
    );
  }
}

/// A category heading followed by [rowCount] service rows, as a box widget.
class ServiceListSkeleton extends StatelessWidget {
  const ServiceListSkeleton({super.key, this.rowCount = 3, this.showAction = false});

  final int rowCount;
  final bool showAction;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ServiceCategorySkeleton(),
          for (var i = 0; i < rowCount; i++) ServiceRowSkeleton(showAction: showAction),
        ],
      ),
    );
  }
}

/// Square-ish tiles in a fixed-column grid, matching a posts/discovery grid.
///
/// Uses a non-scrolling [GridView] so it can sit inside another scroll view.
class PostGridSkeleton extends StatelessWidget {
  const PostGridSkeleton({
    super.key,
    this.crossAxisCount = 3,
    this.spacing = 8,
    this.childAspectRatio = 1,
    this.borderRadius = 12,
    this.padding = EdgeInsets.zero,
    this.itemCount = 9,
    this.scrollable = false,
  });

  final int crossAxisCount;
  final double spacing;
  final double childAspectRatio;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final int itemCount;

  /// When true the grid fills its parent (e.g. a tab body) instead of
  /// shrink-wrapping inside another scroll view.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: GridView.builder(
        shrinkWrap: !scrollable,
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: itemCount,
        itemBuilder: (_, _) => SkeletonBox(borderRadius: borderRadius),
      ),
    );
  }
}

/// Mirrors a [ListTile] with a circular avatar and a single title line.
class ListTileSkeleton extends StatelessWidget {
  const ListTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: SkeletonBox.circle(size: 40),
      title: SkeletonText(
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        widthFactor: 0.55,
      ),
    );
  }
}

/// Mirrors a review card: avatar, reviewer name, star row and two lines of
/// text.
class ReviewCardSkeleton extends StatelessWidget {
  const ReviewCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox.circle(size: 40),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  widthFactor: 0.4,
                ),
                SizedBox(height: 4),
                SkeletonBox(width: 80, height: 14, borderRadius: 7),
                SizedBox(height: 8),
                SkeletonText(style: TextStyle(fontSize: 14, height: 1.4)),
                SkeletonText(style: TextStyle(fontSize: 14, height: 1.4), widthFactor: 0.7),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mirrors the customer `ProfileHeader`: a 120pt bordered avatar, name and a
/// bio line.
class ProfileHeaderSkeleton extends StatelessWidget {
  const ProfileHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        // CircleAvatar radius 56 plus a 4pt border on each side.
        SkeletonBox.circle(size: 120),
        SizedBox(height: 20),
        SkeletonText(
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          width: 180,
        ),
        SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: SkeletonText(style: TextStyle(fontSize: 15, height: 1.4), width: 240),
        ),
      ],
    );
  }
}

/// Mirrors `ProfileMenuTile`: a 42pt icon chip and a title line.
class MenuTileSkeleton extends StatelessWidget {
  const MenuTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      // Icon (22) plus 10pt padding on each side.
      leading: SkeletonBox(width: 42, height: 42, borderRadius: 12),
      title: SkeletonText(
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        widthFactor: 0.45,
      ),
    );
  }
}

/// Mirrors the edit-profile forms: avatar picker, a section title and
/// outlined text fields.
class FormSkeleton extends StatelessWidget {
  const FormSkeleton({super.key, this.fieldCount = 4, this.avatarRadius = 50});

  final int fieldCount;
  final double avatarRadius;

  /// Height of a single-line outlined [TextFormField] with the default
  /// Material 3 density.
  static const double fieldHeight = 56;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: SkeletonBox.circle(size: avatarRadius * 2)),
            const SizedBox(height: 32),
            const SkeletonText(
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              widthFactor: 0.4,
            ),
            for (var i = 0; i < fieldCount; i++) ...[
              const SizedBox(height: 16),
              const SkeletonBox(height: fieldHeight, borderRadius: 12),
            ],
          ],
        ),
      ),
    );
  }
}
