import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/post_model.dart';

class DiscoveryFeedView extends StatelessWidget {
  final List<PostModel> posts;

  const DiscoveryFeedView({super.key, required this.posts});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(child: Text('No posts found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final mediaUrl = post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              if (mediaUrl != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: CachedNetworkImage(
                      imageUrl: mediaUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 400, // Fixed height for feed items
                      placeholder: (context, url) => Container(
                        height: 400,
                        color: Colors.grey.shade200,
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 400,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              
              // Likes and caption
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.favorite, color: Colors.red, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${post.likesCount} likes',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                              ),
                              children: [
                                // Static placeholder for author name as requested
                                const TextSpan(
                                  text: 'Pamper Salon ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: post.caption ?? 'Natural bridal makeup look',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'View all ${post.commentsCount > 0 ? post.commentsCount : 6} comments',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Static placeholder for comment preview
                          RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Jane Doe ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: 'Beautiful'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Static placeholder for add comment section
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.grey.shade300,
                                // child: Icon(Icons.person, size: 16),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Add a comment...',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
