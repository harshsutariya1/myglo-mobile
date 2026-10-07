import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/platform/calendar_bridge.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/snackbar_utils.dart';
import '../../models/booking.dart';
import '../../models/booking_enums.dart';
import '../../models/booking_time.dart';
import 'booking_card.dart';
import 'booking_pills.dart';
import 'booking_summary.dart';

/// The core facts of a booking (who, when, where, status) as one card, for
/// the confirmation and detail screens. [forProvider] shows the client.
class BookingOverviewCard extends StatelessWidget {
  const BookingOverviewCard({super.key, required this.booking, this.forProvider = false, this.trailingRows = const []});

  final Booking booking;
  final bool forProvider;
  final List<Widget> trailingRows;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final name = forProvider ? booking.clientName : booking.providerName;
    final avatar = forProvider ? booking.clientAvatarUrl : booking.providerAvatarUrl;
    final divider = Divider(height: 26, thickness: 1, color: scheme.onSurface.withValues(alpha: 0.07));
    final year = BookingTime.todayIn(booking.timeZone).year;

    return BookingSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PersonAvatar(name: name, url: avatar, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: scheme.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      booking.servicesSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, height: 1.3, color: scheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              BookingStatusPill(status: booking.status),
              PaymentStatusPill(method: booking.paymentMethod, status: booking.paymentStatus),
            ],
          ),
          divider,
          BookingDetailRow(
            icon: Icons.calendar_today_rounded,
            title: Formatters.dateLong(booking.startsAtLocal, currentYear: year),
            subtitle: '${Formatters.timeRange(booking.startsAtLocal, booking.endsAtLocal)} · ${booking.timeZoneLabel}',
          ),
          divider,
          BookingDetailRow(
            icon: booking.isMobile ? Icons.home_outlined : Icons.storefront_outlined,
            title: booking.isMobile ? (forProvider ? "At the client's place" : 'At your place') : 'At the studio',
            subtitle: [
              booking.addressText,
              if (booking.isMobile && booking.distanceKm != null)
                '${Formatters.distanceKm(booking.distanceKm!)} from the studio',
              if ((booking.accessNotes ?? '').isNotEmpty) 'Note: ${booking.accessNotes}',
            ].join('\n'),
          ),
          divider,
          BookingDetailRow(
            icon: Icons.confirmation_number_outlined,
            title: booking.reference,
            subtitle: 'Booking reference',
            trailing: IconButton(
              tooltip: 'Copy reference',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: booking.reference));
                HapticFeedback.selectionClick();
                if (context.mounted) context.showAppSnackBar('Reference copied');
              },
              icon: Icon(Icons.copy_rounded, size: 19, color: scheme.onSurface.withValues(alpha: 0.6)),
            ),
          ),
          ...trailingRows,
        ],
      ),
    );
  }
}

/// Itemised prices of a saved booking.
class BookingPriceCard extends StatelessWidget {
  const BookingPriceCard({super.key, required this.booking, this.forProvider = false});

  final Booking booking;
  final bool forProvider;

  @override
  Widget build(BuildContext context) {
    final cash = booking.paymentMethod == PaymentMethod.cash;
    final note = switch (booking.paymentStatus) {
      PaymentStatus.pending when cash =>
        forProvider ? 'To collect in cash at the appointment.' : 'Pay in cash at your appointment.',
      PaymentStatus.paid => 'Paid${cash ? ' in cash' : ''}.',
      PaymentStatus.voided => 'Nothing to pay.',
      _ => null,
    };
    return BookingSectionCard(
      child: PriceBreakdown(
        lines: [
          for (final item in booking.items)
            (label: item.name, detail: Formatters.duration(item.durationMinutes), cents: item.priceCents),
        ],
        totalCents: booking.totalCents,
        footnote: note,
        platformFeeCents: forProvider ? booking.platformFeeCents ?? 0 : null,
        // Myglo takes no commission on cash bookings.
        noPlatformFeeLabel: cash ? 'None on cash' : 'Free',
      ),
    );
  }
}

/// "Add to calendar" for a booking, through the platform's own event sheet.
/// [forProvider] words the event for the provider (client name and phone).
class AddToCalendarButton extends ConsumerWidget {
  const AddToCalendarButton({super.key, required this.booking, this.expanded = true, this.forProvider = false});

  final Booking booking;
  final bool expanded;
  final bool forProvider;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final cash = booking.paymentMethod == PaymentMethod.cash;
    final total = Formatters.audCents(booking.totalCents);
    final result = await ref.read(calendarBridgeProvider).addEvent(CalendarEvent(
          title: '${booking.servicesSummary} · ${forProvider ? booking.clientName : booking.providerName}',
          start: booking.startsAt,
          end: booking.endsAt,
          location: booking.addressText,
          timeZone: booking.timeZone,
          notes: [
            'Booking ${booking.reference} on Myglo',
            if (forProvider) ...[
              'Client: ${booking.clientName}, ${booking.clientPhone}',
              if (cash) 'Collect $total in cash',
              if ((booking.accessNotes ?? '').isNotEmpty) 'Access: ${booking.accessNotes}',
            ] else ...[
              if (booking.status == BookingStatus.pending) 'Waiting for ${booking.providerName} to confirm',
              if (cash) 'Pay $total in cash at the appointment',
            ],
          ].join('\n'),
        ));
    if (!context.mounted) return;
    switch (result) {
      case CalendarAddResult.saved:
        context.showAppSnackBar('Added to your calendar');
      case CalendarAddResult.denied:
        context.showAppSnackBar('Allow calendar access for Myglo in Settings to add bookings.', isError: true);
      case CalendarAddResult.unavailable:
        context.showAppSnackBar("We couldn't open your calendar on this device.", isError: true);
      case CalendarAddResult.opened || CalendarAddResult.cancelled:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final button = OutlinedButton.icon(
      onPressed: () => _add(context, ref),
      icon: const Icon(Icons.event_available_rounded, size: 20),
      label: const Text('Add to calendar'),
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(0, 52),
        side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.18)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
