import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../../customers/provider_profile/views/widgets/section_states.dart';
import '../controllers/reviews_controllers.dart';
import '../models/review_summary.dart';
import 'review_reply_sheet.dart';
import 'widgets/rating_summary.dart';
import 'widgets/review_card.dart';

/// Every review of a provider or of one service, newest first, under their
/// rating summary. With [canReply] (the provider's own reviews) each review
/// gets a reply action.
class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({
    super.key,
    required this.query,
    required this.title,
    this.providerName,
    this.canReply = false,
  });

  final ReviewQuery query;
  final String title;

  /// Shown above the provider's replies.
  final String? providerName;
  final bool canReply;

  AsyncValue<ReviewSummary> _summary(WidgetRef ref) => switch (query) {
        (serviceId: final String serviceId, providerId: _) => ref.watch(serviceReviewSummaryProvider(serviceId)),
        (providerId: final String providerId, serviceId: null) => ref.watch(providerReviewSummaryProvider(providerId)),
        _ => const AsyncData(ReviewSummary.empty),
      };

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(reviewListProvider(query));
    if (query.serviceId case final String serviceId) {
      ref.invalidate(serviceReviewSummaryProvider(serviceId));
    } else if (query.providerId case final String providerId) {
      ref.invalidate(providerReviewSummaryProvider(providerId));
    }
    try {
      await ref.read(reviewListProvider(query).future);
    } catch (_) {
      // Shown inline by the list.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final summary = _summary(ref);
    final async = ref.watch(reviewListProvider(query));
    final page = async.value;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(title),
      ),
      body: RefreshIndicator(
        color: scheme.primary,
        onRefresh: () => _refresh(ref),
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.extentAfter < 400) ref.read(reviewListProvider(query).notifier).loadMore();
            return false;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: switch (summary) {
                    // The empty state below says it all.
                    AsyncData(:final value) when value.isEmpty => const SizedBox.shrink(),
                    AsyncData(:final value) => RatingSummaryCard(summary: value),
                    AsyncError() => const SizedBox.shrink(),
                    _ => const Shimmer(child: SkeletonBox(height: 132, borderRadius: 16)),
                  },
                ),
              ),
              if (page == null)
                SliverToBoxAdapter(
                  child: switch (async) {
                    AsyncError(:final error) => SectionErrorView(
                        title: "Reviews didn't load",
                        message: describeLoadError(error, subject: 'these reviews'),
                        onRetry: () => ref.invalidate(reviewListProvider(query)),
                      ),
                    _ => const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: ReviewListSkeleton()),
                  },
                )
              else if (page.items.isEmpty)
                const SliverToBoxAdapter(
                  child: SectionEmptyView(
                    icon: Icons.rate_review_outlined,
                    title: 'No reviews yet',
                    message: 'Reviews from clients appear here after their appointments.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  sliver: SliverList.separated(
                    itemCount: page.items.length,
                    separatorBuilder: (_, _) => Divider(height: 36, color: scheme.onSurface.withValues(alpha: 0.08)),
                    itemBuilder: (context, index) {
                      final review = page.items[index];
                      return ReviewCard(
                        review: review,
                        providerName: providerName,
                        showServices: query.serviceId == null,
                        onReply: canReply ? () => showReviewReplySheet(context, review: review) : null,
                      );
                    },
                  ),
                ),
              if (page != null && (page.loadingMore || page.loadMoreFailed))
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: page.loadingMore
                          ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : TextButton(
                              onPressed: () => ref.read(reviewListProvider(query).notifier).loadMore(retry: true),
                              child: const Text("Couldn't load more. Try again"),
                            ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom)),
            ],
          ),
        ),
      ),
    );
  }
}
