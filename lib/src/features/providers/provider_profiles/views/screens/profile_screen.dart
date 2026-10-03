import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:readmore/readmore.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/routing/app_router.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../../customers/provider_profile/views/widgets/provider_services_tab.dart'
    show groupServicesByCategory;
import '../../../../customers/provider_profile/views/widgets/section_states.dart';
import '../../../../discovery_feed/controllers/user_posts_controller.dart';
import '../../../../discovery_feed/views/upload_post_screen.dart';
import '../../../../discovery_feed/views/post_detail_screen.dart';
import '../../controllers/provider_services_controller.dart';
import '../../../../shared/services/views/widgets/service_details_sheet.dart';
import '../../../../shared/services/views/widgets/service_tile.dart';
import '../widgets/service_owner_menu.dart';
import 'add_service_screen.dart';

/// Layout constants shared by the profile header and its skeleton so both
/// occupy the same space.
abstract final class _ProfileMetrics {
  static const double coverHeight = 220;
  static const double sheetOverlap = 32;
  static const double sheetTop = coverHeight - sheetOverlap;
  static const double avatarRadius = 44;
  // Gradient ring (3) + surface gap (3) around the avatar.
  static const double avatarOuterRadius = avatarRadius + 6;
  static const double tabBarHeight = 72;
  static const double pagePadding = 20;
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _showServices = true; // Toggle between Services and Photos

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: userProfileAsync.when(
        loading: () => const _ProfileScreenSkeleton(),
        error: (err, stack) => SafeArea(
          child: Center(
            child: SectionErrorView(
              title: "Your profile didn't load",
              message: describeLoadError(err, subject: 'your profile'),
              onRetry: () => ref.invalidate(userProfileProvider),
            ),
          ),
        ),
        data: (appUser) {
          if (appUser == null) {
            return const Center(child: Text('Not logged in'));
          }

          final userId = appUser.rawUser.id;
          final businessName = appUser.profile.providerName?.trim() ?? '';
          final providerName = businessName.isNotEmpty
              ? businessName
              : (appUser.displayName.isNotEmpty ? appUser.displayName : 'Your business');
          final addressText = appUser.profile.addressText?.trim() ?? '';
          final bio = appUser.profile.bio?.trim() ?? '';

          return RefreshIndicator(
            color: context.colorScheme.primary,
            onRefresh: () async {
              ref.invalidate(userProfileProvider);
              ref.invalidate(userPostsProvider(userId));
              ref.invalidate(providerServicesProvider(userId));
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _ProfileHeader(
                    userId: userId,
                    name: providerName,
                    address: addressText,
                    bio: bio,
                    profilePicUrl: appUser.profile.profilePic,
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedHeaderDelegate(
                    height: _ProfileMetrics.tabBarHeight,
                    builder: (context, overlapsContent) => _TabBarSurface(
                      overlapsContent: overlapsContent,
                      child: _SegmentedToggle(
                        showServices: _showServices,
                        onChanged: (value) => setState(() => _showServices = value),
                      ),
                    ),
                  ),
                ),
                if (_showServices)
                  _ProviderServicesList(userId: userId)
                else
                  _ProviderPostsGrid(userId: userId),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
      ),
    );
  }
}

void _openAddService(BuildContext context) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddServiceScreen()));
}

void _openCreatePost(BuildContext context) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadPostScreen()));
}

String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'M';
  if (parts.length > 1) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  return parts[0].substring(0, math.min(2, parts[0].length)).toUpperCase();
}

/// Cover photo, overlapping identity sheet, stats and quick actions.
class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({
    required this.userId,
    required this.name,
    required this.address,
    required this.bio,
    required this.profilePicUrl,
  });

  final String userId;
  final String name;
  final String address;
  final String bio;
  final String? profilePicUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final serviceCount = ref.watch(providerServicesProvider(userId)).value?.length;
    final postCount = ref.watch(userPostsProvider(userId)).value?.length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover with a scrim so the glass controls stay legible on any photo.
        SizedBox(
          height: _ProfileMetrics.coverHeight,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/images/myglo_cover.png', fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.15),
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Identity sheet overlapping the cover.
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: _ProfileMetrics.sheetTop),
          padding: const EdgeInsets.fromLTRB(
            _ProfileMetrics.pagePadding,
            _ProfileMetrics.avatarOuterRadius + 14,
            _ProfileMetrics.pagePadding,
            8,
          ),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 26,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: scheme.onSurface,
                ),
              ),
              if (address.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: scheme.secondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: muted),
                      ),
                    ),
                  ],
                ),
              ],
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 14),
                ReadMoreText(
                  bio,
                  trimLines: 3,
                  trimMode: TrimMode.Line,
                  trimCollapsedText: ' View more',
                  trimExpandedText: ' View less',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: scheme.onSurface.withValues(alpha: 0.72),
                    fontFamily: 'Muli',
                  ),
                  moreStyle: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.secondary,
                    fontFamily: 'Muli',
                  ),
                  lessStyle: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.secondary,
                    fontFamily: 'Muli',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _StatsLine(serviceCount: serviceCount, postCount: postCount),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Add service',
                      icon: Icons.add_rounded,
                      filled: true,
                      onPressed: () => _openAddService(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      label: 'New post',
                      icon: Icons.photo_camera_outlined,
                      filled: false,
                      onPressed: () => _openCreatePost(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),

        // Avatar straddling the sheet edge.
        Positioned(
          top: _ProfileMetrics.sheetTop - _ProfileMetrics.avatarOuterRadius,
          left: 0,
          right: 0,
          child: Center(child: _ProfileAvatar(name: name, url: profilePicUrl)),
        ),

        // Glass settings control.
        Positioned(
          top: MediaQuery.paddingOf(context).top + 8,
          right: 16,
          child: _GlassIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onPressed: () => context.pushNamed(AppRoute.settings.name),
          ),
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: IconButton(
            tooltip: tooltip,
            padding: EdgeInsets.zero,
            icon: Icon(icon, color: Colors.white, size: 22),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.name, required this.url});

  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Semantics(
      label: '$name profile photo',
      image: true,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, scheme.secondary, scheme.tertiary],
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
          child: CircleAvatar(
            radius: _ProfileMetrics.avatarRadius,
            backgroundColor: scheme.primary,
            backgroundImage: url != null ? CachedNetworkImageProvider(url!) : null,
            child: url == null
                ? Text(
                    _initialsOf(name),
                    style: TextStyle(
                      fontSize: 32,
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Minimal inline counts: "12 Services · 8 Posts".
class _StatsLine extends StatelessWidget {
  const _StatsLine({required this.serviceCount, required this.postCount});

  /// `null` while the count is still loading (or failed to load).
  final int? serviceCount;
  final int? postCount;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final number = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      color: scheme.onSurface,
    );
    final label = TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: muted);

    return Semantics(
      label: '${serviceCount ?? 'Unknown'} services, ${postCount ?? 'Unknown'} posts',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: serviceCount?.toString() ?? '–', style: number),
            TextSpan(text: serviceCount == 1 ? ' Service' : ' Services', style: label),
            TextSpan(text: '   ·   ', style: label),
            TextSpan(text: postCount?.toString() ?? '–', style: number),
            TextSpan(text: postCount == 1 ? ' Post' : ' Posts', style: label),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    const textStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
    final iconWidget = Icon(icon, size: 20);

    return SizedBox(
      height: 50,
      child: filled
          ? FilledButton.icon(
              onPressed: onPressed,
              icon: iconWidget,
              label: Text(label),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                shape: shape,
                textStyle: textStyle,
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: iconWidget,
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.onSurface,
                side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.18)),
                shape: shape,
                textStyle: textStyle,
              ),
            ),
    );
  }
}

/// Pinned background behind the segmented toggle; gains a hairline once
/// content scrolls underneath it.
class _TabBarSurface extends StatelessWidget {
  const _TabBarSurface({required this.overlapsContent, required this.child});

  final bool overlapsContent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(
        horizontal: _ProfileMetrics.pagePadding,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(
            color: overlapsContent
                ? scheme.onSurface.withValues(alpha: 0.08)
                : Colors.transparent,
          ),
        ),
      ),
      child: child,
    );
  }
}

/// iOS-style segmented control with a sliding thumb.
class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({required this.showServices, required this.onChanged});

  final bool showServices;
  final ValueChanged<bool> onChanged;

  static const _animation = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: _animation,
            curve: Curves.easeOutCubic,
            alignment: showServices ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _SegmentLabel(
                  label: 'Services',
                  icon: Icons.content_cut_rounded,
                  selected: showServices,
                  onTap: () => onChanged(true),
                ),
              ),
              Expanded(
                child: _SegmentLabel(
                  label: 'Photos',
                  icon: Icons.grid_view_rounded,
                  selected: !showServices,
                  onTap: () => onChanged(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final color = selected ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.5);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: selected ? scheme.secondary : color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderServicesList extends ConsumerWidget {
  final String userId;
  const _ProviderServicesList({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(providerServicesProvider(userId));

    return servicesAsync.when(
      loading: () => const SliverToBoxAdapter(child: _ServiceListSkeleton()),
      error: (err, stack) => SliverToBoxAdapter(
        child: SectionErrorView(
          title: "Services didn't load",
          message: describeLoadError(err, subject: 'your services'),
          onRetry: () => ref.invalidate(providerServicesProvider(userId)),
        ),
      ),
      data: (services) {
        if (services.isEmpty) {
          return SliverToBoxAdapter(
            child: _EmptyWithAction(
              icon: Icons.content_cut_rounded,
              title: 'No services yet',
              message: 'Add your first service so clients can start booking you.',
              actionLabel: 'Add a service',
              onAction: () => _openAddService(context),
            ),
          );
        }

        final rows = <Widget>[];
        for (final entry in groupServicesByCategory(services).entries) {
          rows.add(_CategoryHeading(label: entry.key, count: entry.value.length));
          for (final service in entry.value) {
            rows.add(ServiceTile(
              service: service,
              onTap: () => showServiceDetailsSheet(context, service: service),
              trailing: ServiceOwnerMenu(service: service),
            ));
          }
        }
        return SliverList.list(children: rows);
      },
    );
  }
}

class _CategoryHeading extends StatelessWidget {
  const _CategoryHeading({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_ProfileMetrics.pagePadding, 16, _ProfileMetrics.pagePadding, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state with a single call to action.
class _EmptyWithAction extends StatelessWidget {
  const _EmptyWithAction({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionEmptyView(icon: icon, title: title, message: message),
        FilledButton(
          onPressed: onAction,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.onSurface,
            foregroundColor: scheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          child: Text(actionLabel),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ProviderPostsGrid extends ConsumerWidget {
  final String userId;
  const _ProviderPostsGrid({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsState = ref.watch(userPostsProvider(userId));

    return postsState.when(
      data: (posts) {
        if (posts.isEmpty) {
          return SliverToBoxAdapter(
            child: _EmptyWithAction(
              icon: Icons.photo_library_outlined,
              title: 'No posts yet',
              message: 'Share your work to show clients what you can do.',
              actionLabel: 'Create a post',
              onAction: () => _openCreatePost(context),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(_ProfileMetrics.pagePadding, 8, _ProfileMetrics.pagePadding, 0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final post = posts[index];
              final imageUrl = post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostDetailScreen(post: post),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl != null)
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Shimmer(
                            child: SkeletonBox(borderRadius: 0),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                          ),
                        )
                      else
                        Container(color: Colors.grey.shade200),
                      if (post.mediaUrls.length > 1)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.collections_rounded, color: Colors.white, size: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }, childCount: posts.length),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: PostGridSkeleton(padding: EdgeInsets.symmetric(horizontal: _ProfileMetrics.pagePadding)),
      ),
      error: (err, stack) => SliverToBoxAdapter(
        child: SectionErrorView(
          title: "Posts didn't load",
          message: describeLoadError(err, subject: 'your posts'),
          onRetry: () => ref.invalidate(userPostsProvider(userId)),
        ),
      ),
    );
  }
}

/// Placeholders matching the category heading and [ServiceTile] cards.
class _ServiceListSkeleton extends StatelessWidget {
  const _ServiceListSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(_ProfileMetrics.pagePadding, 16, _ProfileMetrics.pagePadding, 12),
            child: SkeletonText(
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              widthFactor: 0.4,
            ),
          ),
          ServiceRowSkeleton(showAction: true),
          ServiceRowSkeleton(showAction: true),
        ],
      ),
    );
  }
}

/// Mirrors the loaded layout: cover, overlapping sheet and avatar, name,
/// stats, quick actions and the segmented control.
class _ProfileScreenSkeleton extends StatelessWidget {
  const _ProfileScreenSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Shimmer(
      child: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: _ProfileMetrics.sheetTop + _ProfileMetrics.avatarOuterRadius + 14,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SkeletonBox(height: _ProfileMetrics.coverHeight, borderRadius: 0),
                  ),
                  Positioned(
                    top: _ProfileMetrics.sheetTop - _ProfileMetrics.avatarOuterRadius,
                    left: 0,
                    right: 0,
                    child: Center(child: SkeletonBox.circle(size: _ProfileMetrics.avatarOuterRadius * 2)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _ProfileMetrics.pagePadding),
              child: Column(
                children: [
                  SkeletonText(
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    width: 200,
                  ),
                  SizedBox(height: 8),
                  SkeletonText(style: TextStyle(fontSize: 14), width: 230),
                  SizedBox(height: 16),
                  SkeletonText(style: TextStyle(fontSize: 15), width: 150),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: SkeletonBox(height: 50, borderRadius: 16)),
                      SizedBox(width: 12),
                      Expanded(child: SkeletonBox(height: 50, borderRadius: 16)),
                    ],
                  ),
                  SizedBox(height: 20),
                  SkeletonBox(height: 48, borderRadius: 16),
                ],
              ),
            ),
            _ServiceListSkeleton(),
          ],
        ),
      ),
    );
  }
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  _PinnedHeaderDelegate({required this.height, required this.builder});

  final double height;
  final Widget Function(BuildContext context, bool overlapsContent) builder;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: builder(context, overlapsContent));
  }

  @override
  bool shouldRebuild(_PinnedHeaderDelegate oldDelegate) => true;
}
