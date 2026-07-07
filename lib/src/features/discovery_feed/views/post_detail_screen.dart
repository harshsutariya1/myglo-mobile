import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../models/post_model.dart';
import '../controllers/delete_post_controller.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final PostModel post;
  final bool isAuthor;

  const PostDetailScreen({super.key, required this.post, this.isAuthor = false});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    ref.watch(deletePostControllerProvider);
    
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Post',
          style: TextStyle(
            color: context.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: context.colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: context.colorScheme.onSurface),
        actions: [
          if (widget.isAuthor)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _showDeleteConfirmation(context, ref),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Carousel
            if (widget.post.mediaUrls.isNotEmpty)
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.width,
                    child: PageView.builder(
                      itemCount: widget.post.mediaUrls.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentImageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        return CachedNetworkImage(
                          imageUrl: widget.post.mediaUrls[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(color: context.colorScheme.primary),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 48),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (widget.post.mediaUrls.length > 1)
                    Positioned(
                      bottom: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.post.mediaUrls.length,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == index
                                  ? context.colorScheme.onSurface
                                  : Colors.white.withValues(alpha: 0.5),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              )
            else
              Container(
                height: MediaQuery.of(context).size.width,
                width: double.infinity,
                color: Colors.grey.shade100,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text('No media attached', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),

            Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action buttons (Like, Comment, etc)
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: Icon(Icons.favorite_border, color: context.colorScheme.onSurface, size: 28),
                        constraints: BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                      SizedBox(width: 16),
                      IconButton(
                        onPressed: () {},
                        icon: Icon(Icons.chat_bubble_outline, color: context.colorScheme.onSurface, size: 26),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                      const Spacer(),
                      if (widget.post.taggedProviderId != null)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: context.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.colorScheme.primary.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.storefront, size: 16, color: context.colorScheme.onSurface),
                              SizedBox(width: 4),
                              Text(
                                'Provider Tagged',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Likes Count
                  Text(
                    '${widget.post.likesCount} likes',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),

                  // Caption
                  if (widget.post.caption != null && widget.post.caption!.isNotEmpty)
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Author ', // We would need user details if we want a real username here
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: widget.post.caption!),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Date
                  Text(
                    _formatDate(widget.post.createdAt),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      // Manual formatting since intl may not be in pubspec yet
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close confirmation dialog
              
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              final success = await ref.read(deletePostControllerProvider.notifier).deletePost(
                postId: widget.post.id,
                mediaUrls: widget.post.mediaUrls,
                authorId: widget.post.authorId,
              );
              
              if (success) {
                navigator.pop(); // Go back to profile
              } else {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Failed to delete post')),
                );
              }
            },
            child: Text('Delete', style: TextStyle(color: context.colorScheme.onSurface)),
          ),
        ],
      ),
    );
  }
}
