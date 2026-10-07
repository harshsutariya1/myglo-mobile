import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../shared/bookings/controllers/booking_controllers.dart';
import '../../../shared/bookings/models/booking.dart';
import '../../../shared/bookings/models/booking_repository.dart';
import '../../../shared/bookings/views/widgets/booking_card.dart';
import '../../../shared/bookings/views/widgets/booking_list_view.dart';
import '../../../shared/bookings/views/widgets/booking_segmented_control.dart';
import '../../../shared/notifications/views/notification_bell.dart';

/// The client's bookings: upcoming (requests and confirmed) and past, kept
/// live so a provider accepting, declining or cancelling shows up at once.
class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  int _tab = 0;

  static const _upcoming = (party: BookingParty.client, scope: BookingListScope.upcoming);
  static const _past = (party: BookingParty.client, scope: BookingListScope.past);

  BookingListKey get _key => _tab == 0 ? _upcoming : _past;

  void _open(Booking booking) {
    context.pushNamed(AppRoute.clientBookingDetail.name, pathParameters: {'bookingId': booking.id});
  }

  Future<void> _refresh() async {
    ref.invalidate(bookingListProvider(_key));
    try {
      await ref.read(bookingListProvider(_key).future);
    } catch (_) {
      // Shown inline by the list.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final upcomingCount = ref.watch(bookingListProvider(_upcoming).select((s) => s.value?.items.length));

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: scheme.primary,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bookings',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: scheme.onSurface,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Transform.translate(
                                  offset: const Offset(4, -4),
                                  child: Icon(Icons.auto_awesome, color: scheme.primary, size: 20),
                                ),
                              ],
                            ),
                            Transform.translate(
                              offset: const Offset(0, -6),
                              child: Image.asset('assets/graphics/Underline.png', width: 130, fit: BoxFit.contain),
                            ),
                          ],
                        ),
                      ),
                      const NotificationBell(),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                sliver: SliverToBoxAdapter(
                  child: BookingSegmentedControl(
                    segments: [
                      (label: 'Upcoming', badge: upcomingCount),
                      (label: 'Past', badge: null),
                    ],
                    selected: _tab,
                    onChanged: (index) => setState(() => _tab = index),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                sliver: BookingListSliver(
                  key: ValueKey(_key),
                  listKey: _key,
                  cardBuilder: (context, booking) => BookingCard(
                    booking: booking,
                    muted: _tab == 1,
                    onTap: () => _open(booking),
                  ),
                  empty: _tab == 0
                      ? BookingsEmptyState(
                          icon: Icons.calendar_month_outlined,
                          title: 'No upcoming bookings',
                          message: 'Find a provider you love and book in a few taps.',
                          actionLabel: 'Discover providers',
                          onAction: () => context.goNamed(AppRoute.customerHome.name),
                        )
                      : const BookingsEmptyState(
                          icon: Icons.history_rounded,
                          title: 'No past bookings yet',
                          message: 'Completed and cancelled bookings will show up here.',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
