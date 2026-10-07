import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../../customers/provider_profile/views/widgets/section_states.dart';
import '../../../shared/bookings/controllers/booking_controllers.dart';
import '../../../shared/bookings/models/booking.dart';
import '../../../shared/bookings/models/booking_enums.dart';
import '../../../shared/bookings/models/booking_failure.dart';
import '../../../shared/bookings/views/widgets/booking_overview.dart';
import '../../../shared/bookings/views/widgets/booking_status_banner.dart';
import '../../../shared/bookings/views/widgets/booking_summary.dart';
import 'widgets/provider_booking_sheets.dart';

/// One of the provider's bookings, kept live, with whatever can be done next:
/// answer a request, cancel, complete (recording the cash payment) or mark a
/// no-show.
class ProviderBookingDetailScreen extends ConsumerStatefulWidget {
  const ProviderBookingDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<ProviderBookingDetailScreen> createState() => _ProviderBookingDetailScreenState();
}

class _ProviderBookingDetailScreenState extends ConsumerState<ProviderBookingDetailScreen> {
  /// The quick action in flight (accepting, recording payment).
  bool _busy = false;

  Future<void> _run(Future<Booking> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      HapticFeedback.mediumImpact();
      if (mounted) context.showAppSnackBar(success);
    } on BookingFailure catch (failure) {
      if (mounted) context.showAppSnackBar(failure.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sheet(Booking booking, ProviderBookingAction action) async {
    final updated = await showProviderBookingActionSheet(context, booking: booking, action: action);
    if (updated == null || !mounted) return;
    context.showAppSnackBar(switch (action) {
      ProviderBookingAction.decline => 'Request declined. ${booking.clientName} has been notified.',
      ProviderBookingAction.cancel => 'Appointment cancelled. ${booking.clientName} has been notified.',
      ProviderBookingAction.complete =>
        updated.paymentStatus == PaymentStatus.paid ? 'Completed and marked as paid' : 'Appointment completed',
      ProviderBookingAction.noShow => 'Marked as a no-show',
    });
  }

  Future<void> _recordPayment(Booking booking) async {
    final total = Formatters.audCents(booking.totalCents);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record cash payment?'),
        content: Text('Confirm you received $total in cash from ${booking.clientName}.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Record payment')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() => ref.read(bookingActionsProvider).recordCashPayment(booking.id), 'Payment recorded');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final async = ref.watch(bookingDetailsProvider(widget.bookingId));
    final booking = async.value;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(booking == null ? 'Appointment' : 'Booking ${booking.reference}'),
      ),
      body: switch (booking) {
        final booking? => RefreshIndicator(
            color: scheme.primary,
            onRefresh: () async {
              ref.invalidate(bookingDetailsProvider(widget.bookingId));
              try {
                await ref.read(bookingDetailsProvider(widget.bookingId).future);
              } catch (_) {
                // The previous details stay on screen.
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + MediaQuery.paddingOf(context).bottom),
              children: [
                BookingStatusBanner(booking: booking, now: now, forProvider: true),
                const SizedBox(height: 16),
                BookingOverviewCard(
                  booking: booking,
                  forProvider: true,
                  trailingRows: [
                    Divider(height: 26, thickness: 1, color: scheme.onSurface.withValues(alpha: 0.07)),
                    BookingDetailRow(
                      icon: Icons.phone_outlined,
                      title: booking.clientPhone,
                      subtitle: 'Contact number for ${booking.clientName}',
                      trailing: IconButton(
                        tooltip: 'Copy phone number',
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: booking.clientPhone));
                          HapticFeedback.selectionClick();
                          if (context.mounted) context.showAppSnackBar('Phone number copied');
                        },
                        icon: Icon(Icons.copy_rounded, size: 19, color: scheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                BookingPriceCard(booking: booking, forProvider: true),
                if ((booking.clientNotes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 14),
                  BookingNotice(
                    icon: Icons.edit_note_rounded,
                    title: "${booking.clientName}'s notes",
                    body: booking.clientNotes!,
                  ),
                ],
                if (booking.status == BookingStatus.confirmed && !booking.hasStarted(now)) ...[
                  const SizedBox(height: 14),
                  BookingNotice(
                    icon: Icons.event_available_outlined,
                    title: 'Cancellation policy',
                    body: booking.cancellationWindowHours == 0
                        ? '${booking.clientName} can cancel for free up to the start time.'
                        : '${booking.clientName} can cancel for free until '
                            '${Formatters.dateTimeShort(booking.startsAtLocal.subtract(Duration(hours: booking.cancellationWindowHours)))}. '
                            '${booking.lateFeePercent > 0 ? 'After that, ${Formatters.audCents(booking.lateFeeCents)} '
                                '(${booking.lateFeePercent}%) is owed.' : 'Later cancellations are marked as late${booking.paymentMethod.isCash ? ', with no fee on cash bookings' : ''}.'}',
                  ),
                ],
                const SizedBox(height: 22),
                ..._actions(context, booking, now),
              ],
            ),
          ),
        null when async.hasError => Center(
            child: SingleChildScrollView(
              child: SectionErrorView(
                title: "Appointment didn't load",
                message: describeLoadError(async.error!, subject: 'this appointment'),
                onRetry: () => ref.invalidate(bookingDetailsProvider(widget.bookingId)),
              ),
            ),
          ),
        null when async.hasValue => const Center(
            child: SingleChildScrollView(
              child: SectionEmptyView(
                icon: Icons.search_off_rounded,
                title: 'Appointment not found',
                message: "This booking isn't available on your account.",
              ),
            ),
          ),
        null => const _DetailSkeleton(),
      },
    );
  }

  List<Widget> _actions(BuildContext context, Booking booking, DateTime now) {
    final scheme = context.colorScheme;
    final primary = FilledButton.styleFrom(
      backgroundColor: scheme.onSurface,
      foregroundColor: scheme.surface,
      minimumSize: const Size(0, 54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
    );
    final secondary = OutlinedButton.styleFrom(
      foregroundColor: scheme.onSurface,
      minimumSize: const Size(0, 52),
      side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.15)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
    final destructive = TextButton.styleFrom(
      foregroundColor: AppTheme.destructive,
      minimumSize: const Size(0, 48),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
    Widget spinner() => SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: scheme.surface),
        );

    switch (booking.status) {
      case BookingStatus.pending:
        return [
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(
                      () => ref.read(bookingActionsProvider).accept(booking.id),
                      'Booking confirmed. ${booking.clientName} has been notified.',
                    ),
            style: primary,
            child: _busy ? spinner() : const Text('Accept request'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _busy ? null : () => _sheet(booking, ProviderBookingAction.decline),
            style: secondary,
            child: const Text('Decline'),
          ),
        ];
      case BookingStatus.confirmed when booking.hasStarted(now):
        return [
          FilledButton.icon(
            onPressed: () => _sheet(booking, ProviderBookingAction.complete),
            style: primary,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
            label: const Text('Mark as completed'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _sheet(booking, ProviderBookingAction.noShow),
            style: secondary,
            child: Text("${booking.clientName} didn't show up"),
          ),
        ];
      case BookingStatus.confirmed:
        return [
          AddToCalendarButton(booking: booking, forProvider: true),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => _sheet(booking, ProviderBookingAction.cancel),
            style: destructive,
            child: const Text('Cancel appointment'),
          ),
        ];
      case BookingStatus.completed when booking.paymentStatus == PaymentStatus.pending:
        return [
          FilledButton.icon(
            onPressed: _busy ? null : () => _recordPayment(booking),
            style: primary,
            icon: _busy ? const SizedBox.shrink() : const Icon(Icons.payments_outlined, size: 20),
            label: _busy ? spinner() : const Text('Record cash payment'),
          ),
        ];
      case BookingStatus.completed ||
            BookingStatus.cancelled ||
            BookingStatus.declined ||
            BookingStatus.expired ||
            BookingStatus.noShow:
        return const [];
    }
  }
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
          SkeletonBox(height: 360, borderRadius: 20),
          SizedBox(height: 14),
          SkeletonBox(height: 200, borderRadius: 20),
        ],
      ),
    );
  }
}
