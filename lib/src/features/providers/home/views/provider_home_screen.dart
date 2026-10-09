import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../../shared/bookings/controllers/booking_controllers.dart';
import '../../../shared/bookings/models/booking.dart';
import '../../../shared/bookings/models/booking_failure.dart';
import '../../../shared/bookings/models/booking_repository.dart';
import '../../../shared/bookings/views/widgets/booking_card.dart';
import '../../../shared/bookings/views/widgets/booking_list_view.dart';
import '../../../shared/bookings/views/widgets/booking_segmented_control.dart';
import '../../../shared/notifications/push/push_prompt_card.dart';
import '../../../shared/notifications/views/notification_bell.dart';
import '../../schedule/controllers/provider_schedule_controller.dart';
import 'widgets/booking_setup_card.dart';
import 'widgets/provider_booking_sheets.dart';

/// The provider's appointments: confirmed upcoming bookings (by day),
/// requests waiting for an answer, and past bookings. Everything is live:
/// new bookings and client cancellations appear without a refresh.
class ProviderHomeScreen extends ConsumerStatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  ConsumerState<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends ConsumerState<ProviderHomeScreen> {
  int _tab = 0;

  static const _upcoming = (party: BookingParty.provider, scope: BookingListScope.confirmed);
  static const _requests = (party: BookingParty.provider, scope: BookingListScope.requests);
  static const _past = (party: BookingParty.provider, scope: BookingListScope.past);

  BookingListKey get _key => switch (_tab) {
        0 => _upcoming,
        1 => _requests,
        _ => _past,
      };

  void _open(Booking booking) {
    context.pushNamed(AppRoute.providerBookingDetail.name, pathParameters: {'bookingId': booking.id});
  }

  Future<void> _refresh() async {
    ref.invalidate(bookingListProvider(_key));
    ref.invalidate(bookingListProvider(_requests));
    try {
      await ref.read(bookingListProvider(_key).future);
    } catch (_) {
      // Shown inline by the list.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final requests = ref.watch(bookingListProvider(_requests).select((s) => s.value));
    final requestBadge = requests == null || requests.items.isEmpty ? null : requests.items.length;

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
                            Text(
                              'My appointments',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: scheme.onSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(0, -4),
                              child: Image.asset('assets/graphics/Underline.png', width: 200, fit: BoxFit.contain),
                            ),
                          ],
                        ),
                      ),
                      const NotificationBell(),
                    ],
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PushPromptCard.provider(margin: EdgeInsets.only(bottom: 16)),
                      BookingSetupCard(),
                      _PausedBanner(),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                sliver: SliverToBoxAdapter(
                  child: BookingSegmentedControl(
                    segments: [
                      (label: 'Upcoming', badge: null),
                      (label: 'Requests', badge: requestBadge),
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
                  grouping: _tab == 0 ? BookingListGrouping.day : null,
                  cardBuilder: (context, booking) => BookingCard(
                    booking: booking,
                    showClient: true,
                    muted: _tab == 2,
                    onTap: () => _open(booking),
                    footer: _tab == 1 ? _RequestActions(booking: booking) : null,
                  ),
                  empty: switch (_tab) {
                    0 => BookingsEmptyState(
                        icon: Icons.calendar_month_outlined,
                        title: 'No upcoming appointments',
                        message: 'New bookings appear here the moment clients book.',
                        actionLabel: 'Manage availability',
                        onAction: () => context.pushNamed(AppRoute.workingHours.name),
                      ),
                    1 => const BookingsEmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'No requests waiting',
                        message: 'When a client requests a time, it shows up here for you to accept or decline. '
                            'Cash bookings always come in as requests.',
                      ),
                    _ => const BookingsEmptyState(
                        icon: Icons.history_rounded,
                        title: 'No past appointments yet',
                        message: 'Completed and cancelled appointments will show up here.',
                      ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown while the provider has paused new bookings, with a way to resume.
class _PausedBanner extends ConsumerStatefulWidget {
  const _PausedBanner();

  @override
  ConsumerState<_PausedBanner> createState() => _PausedBannerState();
}

class _PausedBannerState extends ConsumerState<_PausedBanner> {
  bool _busy = false;

  Future<void> _resume() async {
    setState(() => _busy = true);
    try {
      await ref.read(providerScheduleActionsProvider).updateSettings({'accepts_bookings': true});
      HapticFeedback.mediumImpact();
      if (mounted) context.showAppSnackBar("You're taking bookings again");
    } on BookingFailure catch (failure) {
      if (mounted) context.showAppSnackBar(failure.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paused = ref.watch(ownBookingSettingsProvider.select((s) => s.value?.acceptsBookings == false));
    if (!paused) return const SizedBox.shrink();
    final scheme = context.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.pause_circle_outline_rounded, color: AppTheme.warning, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New bookings are paused',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  "Clients can't book you right now. Existing appointments aren't affected.",
                  style: TextStyle(fontSize: 13, height: 1.35, color: scheme.onSurface.withValues(alpha: 0.65)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _busy ? null : _resume,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.onSurface,
              foregroundColor: scheme.surface,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            child: _busy
                ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.surface))
                : const Text('Resume'),
          ),
        ],
      ),
    );
  }
}

/// Accept / decline buttons under a request in the list.
class _RequestActions extends ConsumerStatefulWidget {
  const _RequestActions({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_RequestActions> createState() => _RequestActionsState();
}

class _RequestActionsState extends ConsumerState<_RequestActions> {
  bool _accepting = false;

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await ref.read(bookingActionsProvider).accept(widget.booking.id);
      HapticFeedback.mediumImpact();
      if (mounted) context.showAppSnackBar('Booking confirmed. ${widget.booking.clientName} has been notified.');
    } on BookingFailure catch (failure) {
      if (mounted) context.showAppSnackBar(failure.message, isError: true);
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _decline() async {
    final declined = await showProviderBookingActionSheet(
      context,
      booking: widget.booking,
      action: ProviderBookingAction.decline,
    );
    if (declined != null && mounted) context.showAppSnackBar('Request declined');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final booking = widget.booking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.timer_outlined, size: 15, color: AppTheme.warning),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Respond before ${Formatters.dateTimeShort(booking.startsAtLocal)}',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: scheme.onSurface.withValues(alpha: 0.65)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _accepting ? null : _decline,
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onSurface,
                  minimumSize: const Size(0, 44),
                  side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.15)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: _accepting ? null : _accept,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.onSurface,
                  foregroundColor: scheme.surface,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                child: _accepting
                    ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.surface))
                    : const Text('Accept'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
