import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../customers/provider_profile/views/widgets/section_states.dart';
import '../../../bookings/models/booking.dart';
import '../../controllers/reviews_controllers.dart';
import '../review_composer_screen.dart';
import '../review_reply_sheet.dart';
import 'review_card.dart';
import 'star_rating.dart';

/// On the client's completed booking: an invitation to rate it, or their
/// review with an edit button. Nothing for bookings that can't be reviewed.
class ClientBookingReviewSection extends ConsumerWidget {
  const ClientBookingReviewSection({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!booking.canReview) return const SizedBox.shrink();
    if (booking.reviewId == null) {
      return _ReviewInvite(
        providerName: booking.providerName,
        onRate: (stars) => openReviewComposer(context, booking: booking, initialRating: stars),
      );
    }

    final async = ref.watch(bookingReviewProvider(booking.id));
    return _Frame(
      child: switch (async) {
        AsyncData(value: final review?) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReviewCard(review: review, title: 'Your review', providerName: booking.providerName, showServices: false),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: () => openReviewComposer(context, booking: booking, existing: review),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit review'),
                ),
              ),
            ],
          ),
        // Deleted elsewhere since the booking loaded: offer a fresh review.
        AsyncData() => _ReviewInvite(
            providerName: booking.providerName,
            framed: false,
            onRate: (stars) => openReviewComposer(context, booking: booking, initialRating: stars),
          ),
        AsyncError(:final error) => SectionErrorView(
            title: "Your review didn't load",
            message: describeLoadError(error, subject: 'your review'),
            onRetry: () => ref.invalidate(bookingReviewProvider(booking.id)),
          ),
        _ => const Shimmer(child: ReviewCardSkeleton()),
      },
    );
  }
}

/// On the provider's booking: the client's review, with a public reply.
class ProviderBookingReviewSection extends ConsumerWidget {
  const ProviderBookingReviewSection({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (booking.reviewId == null) return const SizedBox.shrink();
    final async = ref.watch(bookingReviewProvider(booking.id));
    return _Frame(
      title: "${booking.clientName}'s review",
      child: switch (async) {
        AsyncData(value: final review?) => ReviewCard(
            review: review,
            showServices: false,
            providerName: booking.providerName,
            onReply: () => showReviewReplySheet(context, review: review),
          ),
        AsyncData() => const SizedBox.shrink(),
        AsyncError(:final error) => SectionErrorView(
            title: "The review didn't load",
            message: describeLoadError(error, subject: 'this review'),
            onRetry: () => ref.invalidate(bookingReviewProvider(booking.id)),
          ),
        _ => const Shimmer(child: ReviewCardSkeleton()),
      },
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title case final title?) ...[
            Text(title, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: scheme.onSurface)),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// "How was your visit?" with stars that open the composer.
class _ReviewInvite extends StatelessWidget {
  const _ReviewInvite({required this.providerName, required this.onRate, this.framed = true});

  final String providerName;
  final ValueChanged<int> onRate;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final content = Column(
      children: [
        Text(
          'How was your visit?',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: scheme.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          'Rate $providerName to help others choose.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: scheme.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 8),
        StarRatingInput(value: 0, size: 36, onChanged: onRate),
      ],
    );
    if (!framed) return content;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
      ),
      child: content,
    );
  }
}
