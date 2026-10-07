import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../models/booking.dart';
import '../../models/booking_enums.dart';
import 'booking_pills.dart';

/// Big coloured explanation of where a booking stands, worded for whoever
/// is looking at it.
class BookingStatusBanner extends StatelessWidget {
  const BookingStatusBanner({super.key, required this.booking, required this.now, this.forProvider = false});

  final Booking booking;
  final DateTime now;
  final bool forProvider;

  ({String title, String message}) get _copy {
    final provider = booking.providerName;
    final client = booking.clientName;
    final when = Formatters.dateTimeShort(booking.startsAtLocal);
    final fee = booking.cancellationFeeCents > 0 ? Formatters.audCents(booking.cancellationFeeCents) : null;
    String reason(String? text) => (text ?? '').trim().isEmpty ? '' : ' Note: “${text!.trim()}”';

    switch (booking.status) {
      case BookingStatus.pending:
        return forProvider
            ? (title: 'New request', message: '$client is waiting for your answer. Respond before $when, or it expires.')
            : (title: 'Waiting for $provider', message: "Your time is held while they review it. We'll notify you when they respond.");
      case BookingStatus.confirmed when booking.hasStarted(now):
        return forProvider
            ? (title: 'Appointment in progress', message: 'Mark it as completed once you’re done, and record the cash payment.')
            : (title: 'Happening now', message: 'Enjoy your appointment with $provider.');
      case BookingStatus.confirmed:
        return (
          title: 'Confirmed',
          message: forProvider
              ? '$client is booked in for $when.'
              : "You're all set for $when. ${booking.isMobile ? '$provider will come to you.' : 'See you at the studio.'}",
        );
      case BookingStatus.completed:
        return (
          title: 'Completed',
          message: forProvider ? 'Nicely done.' : 'Thanks for visiting $provider. We hope you loved it.',
        );
      case BookingStatus.cancelled:
        final byClient = booking.cancelledBy == CancelledBy.client;
        final who = byClient ? (forProvider ? client : 'You') : (forProvider ? 'You' : provider);
        final late = booking.lateCancellation
            ? ' This was a late cancellation${fee == null ? '' : ' ($fee owed${forProvider ? ' to you' : ' to $provider'})'}.'
            : '';
        return (title: 'Cancelled', message: '$who cancelled this booking.$late${reason(booking.cancellationReason)}');
      case BookingStatus.declined:
        return (
          title: 'Request declined',
          message: forProvider
              ? 'You declined this request.${reason(booking.declineReason)}'
              : "$provider couldn't take this booking.${reason(booking.declineReason)}",
        );
      case BookingStatus.expired:
        return (
          title: 'Request expired',
          message: forProvider
              ? 'This request lapsed before you responded.'
              : "$provider didn't respond before the appointment time.",
        );
      case BookingStatus.noShow:
        return (
          title: 'Missed appointment',
          message: forProvider
              ? 'You marked $client as a no-show.${fee == null ? '' : ' $fee is owed under your policy.'}'
              : '$provider marked this appointment as missed.${fee == null ? '' : ' $fee is owed under their policy.'}',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final style = bookingStatusStyle(booking.status, scheme);
    final copy = _copy;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: style.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: style.color.withValues(alpha: 0.18), shape: BoxShape.circle),
              child: Icon(style.icon, size: 22, color: Color.lerp(style.color, Colors.black, 0.3)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(copy.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                  const SizedBox(height: 3),
                  Text(
                    copy.message,
                    style: TextStyle(fontSize: 14, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.72)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
