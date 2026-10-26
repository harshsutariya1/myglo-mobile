import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../shared/bookings/controllers/booking_controllers.dart';
import '../../../../shared/bookings/models/booking.dart';
import '../../../../shared/bookings/models/booking_enums.dart';
import '../../../../shared/bookings/models/booking_repository.dart';
import '../../../../shared/bookings/models/booking_time.dart';
import '../../../../shared/bookings/views/widgets/booking_card.dart' show PersonAvatar;

const BookingListKey homeUpcomingBookingsKey = (party: BookingParty.client, scope: BookingListScope.upcoming);

/// The client's next appointment, kept live. Shows nothing while loading,
/// when there's nothing booked, or if bookings can't be loaded (the Bookings
/// tab explains that one).
class HomeNextAppointment extends ConsumerWidget {
  const HomeNextAppointment({super.key, required this.now, this.padding = EdgeInsets.zero});

  final DateTime now;

  /// Space around the card, only taken when there is one.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = [
      for (final booking in ref.watch(bookingListProvider(homeUpcomingBookingsKey)).value?.items ?? const <Booking>[])
        if (booking.isUpcoming(now)) booking,
    ];
    if (upcoming.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: NextAppointmentCard(
        booking: upcoming.first,
        moreCount: upcoming.length - 1,
        now: now,
        onTap: () =>
            context.pushNamed(AppRoute.clientBookingDetail.name, pathParameters: {'bookingId': upcoming.first.id}),
        onSeeAll: () => context.goNamed(AppRoute.bookings.name),
      ),
    );
  }
}

/// `Today`, `Tomorrow`, `Happening now` or `Wed 8 Oct`, in the provider's
/// time zone.
String appointmentDayLabel(Booking booking, DateTime now) {
  if (!booking.startsAt.isAfter(now)) return 'Happening now';
  final today = BookingTime.todayIn(booking.timeZone, now: now);
  final day = BookingTime.dateOf(booking.startsAtLocal);
  return switch (day.difference(today).inDays) {
    0 => 'Today',
    1 => 'Tomorrow',
    _ => Formatters.dateShort(booking.startsAtLocal),
  };
}

/// Dark, glowing card for the next appointment.
class NextAppointmentCard extends StatelessWidget {
  const NextAppointmentCard({
    super.key,
    required this.booking,
    required this.moreCount,
    required this.now,
    required this.onTap,
    required this.onSeeAll,
  });

  final Booking booking;

  /// Other upcoming bookings after this one.
  final int moreCount;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onSeeAll;

  static const _ink = Color(0xFF1E0A10);

  @override
  Widget build(BuildContext context) {
    final day = appointmentDayLabel(booking, now);
    final time = Formatters.timeRange(booking.startsAtLocal, booking.endsAtLocal);
    final pending = booking.status == BookingStatus.pending;
    final statusColor = pending ? AppTheme.warning : AppTheme.success;
    final statusLabel = pending ? 'Awaiting confirmation' : 'Confirmed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: 'Up next: ${booking.servicesSummary} with ${booking.providerName}, $day, $time, $statusLabel',
          excludeSemantics: true,
          child: Material(
            color: _ink,
            borderRadius: BorderRadius.circular(26),
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            child: InkWell(
              onTap: onTap,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(1.1, -1.2),
                    radius: 1.4,
                    colors: [
                      AppTheme.primaryPink.withValues(alpha: 0.55),
                      AppTheme.burntOrange.withValues(alpha: 0.18),
                      _ink.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'UP NEXT',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Spacer(),
                          Flexible(
                            flex: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    pending ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                                    size: 12,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      statusLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: statusColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        booking.servicesSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          PersonAvatar(name: booking.providerName, url: booking.providerAvatarUrl, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              booking.providerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_rounded, size: 18, color: AppTheme.peach),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: day,
                                      style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
                                    ),
                                    TextSpan(text: '  ·  $time'),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                            Container(
                              width: 30,
                              height: 30,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: [AppTheme.primaryPink, AppTheme.burntOrange]),
                              ),
                              child: const Icon(Icons.arrow_forward_rounded, size: 17, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (moreCount > 0)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: context.colorScheme.secondary,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
              child: Text('+$moreCount more upcoming'),
            ),
          ),
      ],
    );
  }
}
