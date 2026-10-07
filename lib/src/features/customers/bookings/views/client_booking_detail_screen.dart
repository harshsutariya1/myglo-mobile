import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../../shared/bookings/controllers/booking_controllers.dart';
import '../../../shared/bookings/models/booking.dart';
import '../../../shared/bookings/models/booking_enums.dart';
import '../../../shared/bookings/models/cancellation_policy.dart';
import '../../../shared/bookings/views/widgets/booking_overview.dart';
import '../../../shared/bookings/views/widgets/booking_status_banner.dart';
import '../../../shared/bookings/views/widgets/booking_summary.dart';
import '../../provider_profile/controllers/public_provider_profile_controller.dart';
import '../../provider_profile/views/widgets/provider_action_sheets.dart';
import '../../provider_profile/views/widgets/section_states.dart';
import 'cancel_booking_sheet.dart';

/// One of the client's bookings, kept live: status changes made by the
/// provider (accepting, declining, cancelling, completing) appear at once.
class ClientBookingDetailScreen extends ConsumerWidget {
  const ClientBookingDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  Future<void> _cancel(BuildContext context, Booking booking) async {
    final cancelled = await showCancelBookingSheet(context, booking: booking);
    if (cancelled != null && context.mounted) {
      context.showAppSnackBar(
        cancelled.lateCancellation ? 'Booking cancelled (late cancellation)' : 'Booking cancelled',
      );
    }
  }

  Future<void> _contact(BuildContext context, WidgetRef ref, String providerId) async {
    try {
      final provider = await ref.read(publicProviderProfileProvider(providerId).future);
      if (!context.mounted) return;
      if (provider == null) {
        context.showAppSnackBar("This provider isn't on Myglo any more.", isError: true);
        return;
      }
      await showProviderContactSheet(context, provider);
    } catch (e) {
      if (context.mounted) {
        context.showAppSnackBar(describeLoadError(e, subject: "the provider's contact details"), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final async = ref.watch(bookingDetailsProvider(bookingId));
    final booking = async.value;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(booking == null ? 'Booking' : 'Booking ${booking.reference}'),
      ),
      body: switch (booking) {
        final booking? => RefreshIndicator(
            color: scheme.primary,
            onRefresh: () async {
              ref.invalidate(bookingDetailsProvider(bookingId));
              try {
                await ref.read(bookingDetailsProvider(bookingId).future);
              } catch (_) {
                // The previous details stay on screen.
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + MediaQuery.paddingOf(context).bottom),
              children: [
                BookingStatusBanner(booking: booking, now: now),
                const SizedBox(height: 16),
                BookingOverviewCard(booking: booking),
                const SizedBox(height: 14),
                BookingPriceCard(booking: booking),
                if ((booking.clientNotes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 14),
                  BookingNotice(icon: Icons.edit_note_rounded, title: 'Your notes', body: booking.clientNotes!),
                ],
                if (booking.canCancel(now)) ...[
                  const SizedBox(height: 14),
                  BookingNotice(
                    icon: Icons.event_available_outlined,
                    title: 'Cancellation policy',
                    body: booking.status == BookingStatus.pending
                        ? 'You can withdraw this request for free until the provider responds.'
                        : CancellationPolicy.forBooking(
                            freeUntilLocal:
                                booking.startsAtLocal.subtract(Duration(hours: booking.cancellationWindowHours)),
                            windowHours: booking.cancellationWindowHours,
                            feePercent: booking.cancellationFeePercent,
                            totalCents: booking.totalCents,
                          ),
                  ),
                ],
                const SizedBox(height: 22),
                if (booking.isUpcoming(now)) AddToCalendarButton(booking: booking),
                if (booking.providerId != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _contact(context, ref, booking.providerId!),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                          label: const Text('Contact'),
                          style: _secondaryStyle(scheme),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.pushNamed(
                            booking.status.isActive ? AppRoute.publicProviderProfile.name : AppRoute.selectServices.name,
                            pathParameters: {'id': booking.providerId!},
                          ),
                          icon: Icon(booking.status.isActive ? Icons.storefront_outlined : Icons.replay_rounded, size: 18),
                          label: Text(booking.status.isActive ? 'View provider' : 'Book again'),
                          style: _secondaryStyle(scheme),
                        ),
                      ),
                    ],
                  ),
                ],
                if (booking.canCancel(now)) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => _cancel(context, booking),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.destructive,
                      minimumSize: const Size(0, 48),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    child: Text(booking.status == BookingStatus.pending ? 'Withdraw request' : 'Cancel booking'),
                  ),
                ],
              ],
            ),
          ),
        null when async.hasError => Center(
            child: SingleChildScrollView(
              child: SectionErrorView(
                title: "Booking didn't load",
                message: describeLoadError(async.error!, subject: 'this booking'),
                onRetry: () => ref.invalidate(bookingDetailsProvider(bookingId)),
              ),
            ),
          ),
        null when async.hasValue => const Center(
            child: SingleChildScrollView(
              child: SectionEmptyView(
                icon: Icons.search_off_rounded,
                title: 'Booking not found',
                message: "This booking isn't available on your account.",
              ),
            ),
          ),
        null => const _DetailSkeleton(),
      },
    );
  }

  static ButtonStyle _secondaryStyle(ColorScheme scheme) => OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(0, 50),
        side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.15)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
      );
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: const [
          SkeletonBox(height: 92, borderRadius: 20),
          SizedBox(height: 16),
          SkeletonBox(height: 320, borderRadius: 20),
          SizedBox(height: 14),
          SkeletonBox(height: 180, borderRadius: 20),
        ],
      ),
    );
  }
}
