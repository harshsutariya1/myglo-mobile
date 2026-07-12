import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/post_model.dart';


class DiscoveryGridView extends StatelessWidget {
  final List<PostModel> posts;

  const DiscoveryGridView({super.key, required this.posts});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(child: Text('No posts found.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8, // Adjust based on visual preference
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final mediaUrl = post.mediaUrls.isNotEmpty ? post.mediaUrls.first : null;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: mediaUrl != null
              ? CachedNetworkImage(
                  imageUrl: mediaUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade200,
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.error),
                  ),
                )
              : Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image_not_supported),
                ),
        );
      },
    );
  }
}
