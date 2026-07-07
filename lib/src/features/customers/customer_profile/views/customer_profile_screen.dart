import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../shared/authentication/models/auth_repository.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../discovery_feed/views/upload_post_screen.dart';
import '../../../discovery_feed/views/post_detail_screen.dart';
import '../../../discovery_feed/controllers/user_posts_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'edit_customer_profile_screen.dart';

class CustomerProfileScreen extends ConsumerWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: TextStyle(
            color: context.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: context.colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add_box_outlined, color: context.colorScheme.onSurface),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UploadPostScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: context.colorScheme.onSurface),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                useRootNavigator: false,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) {
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.logout, color: Colors.red),
                            ),
                            title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
                            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                            onTap: () {
                              Navigator.pop(context);
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text('Confirm Logout'),
                                    content: const Text('Are you sure you want to log out?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          Navigator.pop(context);
                                          await ref.read(authRepositoryProvider).signOut();
                                        },
                                        child: const Text(
                                          'Log Out',
                                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: profileState.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found'));
          }

          return RefreshIndicator(
            color: context.colorScheme.onSurface,
            onRefresh: () async {
              debugPrint('Customer profile refreshed');
              ref.invalidate(userProfileProvider);
              ref.invalidate(userPostsProvider(profile.profile.id));
              // Small delay for UI feedback
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: context.colorScheme.primary.withValues(alpha: 0.2),
                            backgroundImage: profile.profile.profilePic != null
                                ? CachedNetworkImageProvider(profile.profile.profilePic!)
                                : null,
                            child: profile.profile.profilePic == null
                                ? Text(
                                    profile.displayName.isNotEmpty
                                        ? profile.displayName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 36,
                                      color: context.colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _CustomerPostCount(userId: profile.profile.id),
                                _buildStatColumn(context, 'Followers', profile.profile.followersCount.toString()),
                                _buildStatColumn(context, 'Following', profile.profile.followingCount.toString()),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        profile.displayName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.colorScheme.onSurface,
                        ),
                      ),
                      if (profile.profile.bio != null && profile.profile.bio!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          profile.profile.bio!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EditCustomerProfileScreen(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.colorScheme.onSurface,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _CustomerPostsGrid(userId: profile.profile.id),
                SizedBox(height: 24),
              ],
            ),
          ));
        },
        loading: () => Center(child: CircularProgressIndicator(color: context.colorScheme.onSurface)),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildStatColumn(BuildContext context, String label, String count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: context.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CustomerPostCount extends ConsumerWidget {
  final String userId;
  const _CustomerPostCount({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsState = ref.watch(userPostsProvider(userId));
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          postsState.value?.length.toString() ?? '-',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: context.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Posts',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: context.colorScheme.primary.withValues(alpha: 0.3), width: 2),
                  ),
                  child: Icon(
                    Icons.grid_off_rounded,
                    size: 48,
                    color: context.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'No posts available',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share photos and videos with your followers.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UploadPostScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colorScheme.onSurface,
                    foregroundColor: context.colorScheme.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Upload Post',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final imageUrl = post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null;
            
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostDetailScreen(post: post, isAuthor: true),
                  ),
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey.shade200),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, color: Colors.grey),
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
            );
          },
        );
      },
      loading: () => Padding(
        padding: EdgeInsets.all(40.0),
        child: Center(
          child: CircularProgressIndicator(color: context.colorScheme.primary),
        ),
      ),
      error: (err, stack) => Padding(
        padding: const EdgeInsets.all(40.0),
        child: Center(
          child: Text('Error loading posts: $err', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}
