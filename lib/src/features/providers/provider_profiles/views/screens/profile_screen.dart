import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:readmore/readmore.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/routing/app_router.dart';
import '../../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../../discovery_feed/controllers/user_posts_controller.dart';
import '../../../../discovery_feed/views/upload_post_screen.dart';
import '../../../../discovery_feed/views/post_detail_screen.dart';
import '../../controllers/provider_services_controller.dart';
import 'add_service_screen.dart';
import '../../models/service_model.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _showServices = true; // Toggle between Services and Photos

  String _getInitials(String name) {
    if (name.isEmpty) return 'KB';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, math.min(2, name.length)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: userProfileAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: context.colorScheme.primary),
        ),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
        ),
        data: (appUser) {
          if (appUser == null) {
            return const Center(child: Text('Not logged in'));
          }

          final providerName =
              (appUser.providerDetails?.providerName?.isNotEmpty == true)
              ? appUser.providerDetails!.providerName!
              : (appUser.displayName.isNotEmpty
                    ? appUser.displayName
                    : "Korea Beauty");

          final addressText =
              (appUser.providerDetails?.addressText?.isNotEmpty == true)
              ? appUser.providerDetails!.addressText!
              : "1 Collins Street, Melbourne VIC";

          final bio = appUser.profile.bio;

          final profilePicUrl = appUser.profile.profilePic;

          return RefreshIndicator(
            color: context.colorScheme.primary,
            onRefresh: () async {
              ref.invalidate(userProfileProvider);
              ref.invalidate(userPostsProvider(appUser.rawUser.id));
              ref.invalidate(providerServicesProvider(appUser.rawUser.id));
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 1. Cover Photo & Profile Info Section
                SliverToBoxAdapter(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Info section (drawn below cover image)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(
                          top: 280,
                        ), // Start after cover image height
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          children: [
                            const SizedBox(
                              height: 60,
                            ), // Push content below overlapping avatar
                            // Business Name
                            Text(
                              providerName,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: context.colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            // Address
                            Text(
                              addressText,
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            // Bio
                            if (bio != null && bio.isNotEmpty) ...[
                                ReadMoreText(
                                  bio,
                                  trimLines: 3,
                                  colorClickableText: Colors.black,
                                  trimMode: TrimMode.Line,
                                  trimCollapsedText: ' View more...',
                                  trimExpandedText: ' View less',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey.shade700,
                                    height: 1.4,
                                    fontFamily: 'Muli',
                                  ),
                                  moreStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontFamily: 'Muli',
                                  ),
                                  lessStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontFamily: 'Muli',
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ]
                          ],
                        ),
                      ),

                      // Cover Photo (drawn on top of info background, though info is margin'd)
                      Container(
                        height: 280,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: AssetImage(
                              'assets/images/myglo_cover.png',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      // Top Right Actions (Settings & More)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        right: 16,
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.settings_outlined,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                onPressed: () {
                                  context.pushNamed(AppRoute.settings.name);
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_horiz,
                                  color: Colors.white,
                                ), // Using more_horiz for 3 dots as it's common
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                onSelected: (value) {
                                  if (value == 'create_post') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const UploadPostScreen(),
                                      ),
                                    );
                                  } else if (value == 'add_service') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AddServiceScreen(),
                                      ),
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'create_post',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.post_add,
                                          size: 20,
                                          color: Colors.black87,
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Create Post',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'add_service',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.add_business,
                                          size: 20,
                                          color: Colors.black87,
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Add Services',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Overlapping Profile Picture
                      Positioned(
                        top:
                            280 -
                            52, // 280 (cover height) minus 52 (avatar radius)
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.colorScheme.surface,
                                width: 4,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 52,
                              backgroundColor: context
                                  .colorScheme
                                  .primary, // Pink background
                              backgroundImage: profilePicUrl != null
                                  ? CachedNetworkImageProvider(profilePicUrl)
                                  : null,
                              child: profilePicUrl == null
                                  ? Text(
                                      _getInitials(providerName),
                                      style: TextStyle(
                                        fontSize: 38,
                                        color: context.colorScheme.onPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Segmented Tab Bar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    minHeight: 68,
                    maxHeight: 68,
                    child: Container(
                      color: context.colorScheme.surface,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 10.0,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _showServices = true),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _showServices
                                        ? const Color(0xFFFFF0EE)
                                        : Colors
                                              .transparent, // very light peach/orange
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Services',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _showServices
                                          ? context.colorScheme.secondary
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _showServices = false),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: !_showServices
                                        ? const Color(0xFFFFF0EE)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Photos',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: !_showServices
                                          ? context.colorScheme.secondary
                                          : Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Content Area
                if (_showServices)
                  _ProviderServicesList(userId: appUser.rawUser.id)
                else
                  _ProviderPostsGrid(userId: appUser.rawUser.id),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        },
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
      loading: () => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Center(
            child: CircularProgressIndicator(
              color: context.colorScheme.primary,
            ),
          ),
        ),
      ),
      error: (err, stack) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Center(
            child: Text(
              'Error: $err',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
      data: (services) {
        if (services.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Center(
                child: Text(
                  'No services available yet.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ),
          );
        }

        // Group services by category
        final groupedServices = <String, List<ServiceModel>>{};
        for (final service in services) {
          final cat = service.category?.isNotEmpty == true ? service.category! : 'Other Services';
          groupedServices.putIfAbsent(cat, () => []).add(service);
        }

        // Flatten to a single list of headers (String) and items (ServiceModel)
        final items = [];
        for (final entry in groupedServices.entries) {
          items.add(entry.key);
          items.addAll(entry.value);
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final item = items[index];

            if (item is String) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.colorScheme.onSurface,
                  ),
                ),
              );
            }

            final service = item as ServiceModel;
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: service.imageUrl ?? 'https://images.unsplash.com/photo-1616683693504-3ea7e9ad6fec?auto=format&fit=crop&q=80&w=200',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade200,
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Service Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: context.colorScheme.onSurface,
                              ),
                            ),
                            if (service.description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                service.description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              '\$${service.price.toStringAsFixed(0)}  •  ${service.durationMinutes >= 60 ? '${service.durationMinutes ~/ 60} hour${service.durationMinutes % 60 > 0 ? ' ${service.durationMinutes % 60} min' : ''}' : '${service.durationMinutes} min'}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(height: 1, color: Colors.grey.shade200, thickness: 1),
                ],
              ),
            );
          }, childCount: items.length),
        );
      },
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
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Center(
                child: Text(
                  'No posts available yet.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final post = posts[index];
              final imageUrl = post.mediaUrls.isNotEmpty
                  ? post.mediaUrls.first
                  : null;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PostDetailScreen(post: post, isAuthor: true),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl != null)
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: Colors.grey.shade200),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      else
                        Container(color: Colors.grey.shade300),
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
              );
            }, childCount: posts.length),
          ),
        );
      },
      loading: () => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Center(
            child: CircularProgressIndicator(
              color: context.colorScheme.primary,
            ),
          ),
        ),
      ),
      error: (err, stack) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Center(
            child: Text(
              'Error loading posts: $err',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => math.max(maxHeight, minHeight);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
