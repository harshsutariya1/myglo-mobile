import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton/skeletons.dart';
import '../../customers/provider_profile/views/widgets/section_states.dart';
import '../../shared/authentication/controllers/user_profile_provider.dart';
import '../controllers/post_detail_controller.dart';
import 'post_detail_screen.dart';

/// A post opened by id: from a shared link (`/p/:id`) or a review's photos.
/// Shows a friendly message when the post was deleted or isn't public.
class SharedPostScreen extends ConsumerWidget {
  const SharedPostScreen({super.key, required this.postId});

  final String postId;

  void _back(BuildContext context, WidgetRef ref) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    // Opened from a link with nothing underneath.
    final isProvider = ref.read(userProfileProvider).value?.isProvider ?? false;
    context.goNamed(isProvider ? AppRoute.providerHome.name : AppRoute.customerHome.name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(postByIdProvider(postId));
    final scheme = context.colorScheme;

    if (async case AsyncData(value: final post?)) {
      return PostDetailScreen(post: post, onBack: () => _back(context, ref));
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        leading: BackButton(onPressed: () => _back(context, ref)),
        title: const Text('Post'),
      ),
      body: switch (async) {
        AsyncError(:final error) => Center(
            child: SingleChildScrollView(
              child: SectionErrorView(
                title: "Post didn't load",
                message: describeLoadError(error, subject: 'this post'),
                onRetry: () => ref.invalidate(postByIdProvider(postId)),
              ),
            ),
          ),
        AsyncData() => const Center(
            child: SingleChildScrollView(
              child: SectionEmptyView(
                icon: Icons.hide_image_outlined,
                title: 'Post not available',
                message: 'It may have been deleted, or it isn\'t public yet.',
              ),
            ),
          ),
        _ => const Shimmer(
            child: Column(
              children: [
                AspectRatio(aspectRatio: 4 / 5, child: SkeletonBox(borderRadius: 0)),
                SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: SkeletonText(style: TextStyle(fontSize: 15, height: 1.5)),
                ),
              ],
            ),
          ),
      },
    );
  }
}
