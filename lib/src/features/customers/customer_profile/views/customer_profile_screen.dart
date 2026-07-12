import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../discovery_feed/views/upload_post_screen.dart';
import '../../../discovery_feed/views/post_detail_screen.dart';
import '../../../discovery_feed/controllers/user_posts_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'edit_customer_profile_screen.dart';
import 'account_settings_screen.dart';
import 'widgets/profile_menu_tile.dart';
import 'widgets/profile_header.dart';

class CustomerProfileScreen extends ConsumerWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: profileState.when(
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('Profile not found'));
            }

            return RefreshIndicator(
              color: context.colorScheme.primary,
              onRefresh: () async {
                ref.invalidate(userProfileProvider);
                ref.invalidate(userPostsProvider(profile.profile.id));
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),

                    // Profile Header Component
                    ProfileHeader(
                      displayName: profile.displayName,
                      profilePicUrl: profile.profile.profilePic,
                      bio: profile.profile.bio,
                      onEditTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const EditCustomerProfileScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // Main Actions
                    ProfileMenuTile(
                      title: 'Following',
                      icon: Icons.people_outline,
                      onTap: () => _showFollowingsSheet(context),
                    ),
                    ProfileMenuTile(
                      title: 'Posts',
                      icon: Icons.grid_on,
                      onTap: () =>
                          _showPostsSheet(context, profile.profile.id, ref),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Divider(color: Colors.grey.shade300),
                    ),

                    // App Features
                    ProfileMenuTile(
                      title: 'Payment Methods',
                      icon: Icons.payment,
                      onTap: () => _showUnderDevelopment(context),
                    ),
                    ProfileMenuTile(
                      title: 'Rewards',
                      icon: Icons.card_giftcard,
                      onTap: () => _showUnderDevelopment(context),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Divider(color: Colors.grey.shade300),
                    ),

                    // Support & Info
                    ProfileMenuTile(
                      title: 'Help Centre',
                      icon: Icons.help_outline,
                      onTap: () => _showUnderDevelopment(context),
                    ),
                    ProfileMenuTile(
                      title: 'About',
                      icon: Icons.info_outline,
                      onTap: () => _showUnderDevelopment(context),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Divider(color: Colors.grey.shade300),
                    ),

                    // Account Settings Link
                    ProfileMenuTile(
                      title: 'Account Settings',
                      icon: Icons.settings_outlined,
                      iconColor: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AccountSettingsScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            );
          },
          loading: () => Center(
            child: CircularProgressIndicator(
              color: context.colorScheme.primary,
            ),
          ),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: context.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Error: $err',
                  style: TextStyle(color: context.colorScheme.error),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUnderDevelopment(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.construction, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text(
              'Feature under development',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showFollowingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Following',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey.shade300),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: context.colorScheme.onSurface.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No following yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'When you follow people, you\'ll see them here.',
                          style: TextStyle(
                            color: context.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPostsSheet(BuildContext context, String userId, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your Posts',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: context.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Divider(height: 1, color: Colors.grey.shade300),
                    ],
                  ),
                ),
                SliverToBoxAdapter(child: _CustomerPostsGrid(userId: userId)),
              ],
            );
          },
        );
      },
    );
  }
}

class _CustomerPostsGrid extends ConsumerWidget {
  final String userId;
  const _CustomerPostsGrid({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsState = ref.watch(userPostsProvider(userId));

    return postsState.when(
      data: (posts) {
        if (posts.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 60.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.photo_camera_outlined,
                    size: 48,
                    color: context.colorScheme.primary.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Capture the Moment',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Share your photos and videos with your community.',
                  style: TextStyle(
                    fontSize: 15,
                    color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UploadPostScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_a_photo_outlined, size: 20),
                  label: const Text(
                    'Upload First Post',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colorScheme.primary,
                    foregroundColor: context.colorScheme.onPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
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
                        placeholder: (context, url) => Container(
                          color: context.colorScheme.surfaceContainerHighest,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: context.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: context.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: context.colorScheme.surfaceContainerHighest,
                      ),
                    if (post.mediaUrls.length > 1)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.collections,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.all(40.0),
        child: Center(
          child: CircularProgressIndicator(color: context.colorScheme.primary),
        ),
      ),
      error: (err, stack) => Padding(
        padding: const EdgeInsets.all(40.0),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                color: context.colorScheme.error,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                'Could not load posts',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
