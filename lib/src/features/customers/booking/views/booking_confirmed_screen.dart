import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../../shared/bookings/controllers/booking_controllers.dart';
import '../../../shared/bookings/models/booking.dart';
import '../../../shared/bookings/models/booking_enums.dart';
import '../../../shared/bookings/views/widgets/booking_overview.dart';
import '../../../shared/bookings/views/widgets/booking_summary.dart';
import '../../../shared/notifications/push/push_prompt_card.dart';
import '../../provider_profile/views/widgets/section_states.dart';

/// Shown after a booking is placed: what happens next, the reference, a
/// summary, and ways to keep it (calendar) or move on.
///
/// [initial] is the booking just created, so nothing loads in between; the
/// screen still refreshes live (e.g. a request accepted while it's open).
class BookingConfirmedScreen extends ConsumerWidget {
  const BookingConfirmedScreen({super.key, required this.bookingId, this.initial});

  final String bookingId;
  final Booking? initial;

  void _home(BuildContext context) => context.goNamed(AppRoute.customerHome.name);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final async = ref.watch(bookingDetailsProvider(bookingId));
    final booking = async.value ?? initial;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _home(context);
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: switch (booking) {
            final booking? => _Confirmation(booking: booking, onHome: () => _home(context)),
            null when async.hasError => Center(
                child: SingleChildScrollView(
                  child: SectionErrorView(
                    title: "We couldn't load your booking",
                    message: describeLoadError(async.error!, subject: 'your booking'),
                    onRetry: () => ref.invalidate(bookingDetailsProvider(bookingId)),
                  ),
                ),
              ),
            null when async.hasValue => Center(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SectionEmptyView(
                        icon: Icons.search_off_rounded,
                        title: 'Booking not found',
                        message: "This booking isn't available on your account.",
                      ),
                      FilledButton(onPressed: () => _home(context), child: const Text('Back to home')),
                    ],
                  ),
                ),
              ),
            null => const Shimmer(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      SizedBox(height: 40),
                      SkeletonBox.circle(size: 112),
                      SizedBox(height: 24),
                      SkeletonText(style: TextStyle(fontSize: 28), widthFactor: 0.6),
                      SizedBox(height: 28),
                      SkeletonBox(height: 300, borderRadius: 20),
                    ],
                  ),
                ),
              ),
          },
        ),
      ),
    );
  }
}

class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.booking, required this.onHome});

  final Booking booking;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final pending = booking.status == BookingStatus.pending;
    final confirmed = booking.status == BookingStatus.confirmed;
    final title = pending
        ? 'Request sent!'
        : confirmed
            ? "You're booked!"
            : 'Booking ${booking.status.label.toLowerCase()}';
    final message = pending
        ? "${booking.providerName} confirms bookings personally. We'll notify you as soon as they reply. "
            'Your time is held in the meantime.'
        : confirmed
            ? "${booking.providerName} is expecting you. You'll find this booking under Bookings, and we'll remind "
                'you before your appointment.'
            : 'This booking was updated since you made it. See the latest details below.';

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          sliver: SliverList.list(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Close',
                  onPressed: onHome,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              const SizedBox(height: 4),
              Center(child: _SuccessBadge(pending: pending)),
              const SizedBox(height: 22),
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: scheme.onSurface),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.5, color: scheme.onSurface.withValues(alpha: 0.65)),
                ),
              ),
              const SizedBox(height: 26),
              BookingOverviewCard(booking: booking),
              const SizedBox(height: 14),
              BookingPriceCard(booking: booking),
              if (booking.status.isActive) const PushPromptCard.booking(margin: EdgeInsets.only(top: 14)),
              if (pending) ...[
                const SizedBox(height: 14),
                const BookingNotice(
                  icon: Icons.notifications_active_outlined,
                  color: AppTheme.warning,
                  title: 'Keep an eye on your notifications',
                  body: "If the provider can't take this time, you'll be told straight away so you can pick another.",
                ),
              ],
            ],
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (booking.status.isActive) ...[
                  AddToCalendarButton(booking: booking),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => context.goNamed(AppRoute.bookings.name),
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.onSurface,
                      foregroundColor: scheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('View my bookings'),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: onHome,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurface.withValues(alpha: 0.7),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Back to home'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Animated check (or hourglass for requests) with soft rings.
class _SuccessBadge extends StatefulWidget {
  const _SuccessBadge({required this.pending});

  final bool pending;

  @override
  State<_SuccessBadge> createState() => _SuccessBadgeState();
}

class _SuccessBadgeState extends State<_SuccessBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (_controller.isDismissed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOutBack.transform(_controller.value.clamp(0.0, 1.0));
          final ring = Curves.easeOut.transform(_controller.value);
          return SizedBox.square(
            dimension: 128,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (final (scale, alpha) in [(1.0, 0.10), (0.78, 0.16)])
                  Transform.scale(
                    scale: scale * (0.6 + 0.4 * ring),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary.withValues(alpha: alpha * ring),
                      ),
                    ),
                  ),
                Transform.scale(
                  scale: math.max(0, t) * 0.62,
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: widget.pending
                            ? [AppTheme.warning, AppTheme.burntOrange]
                            : [scheme.primary, scheme.secondary],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.pending ? AppTheme.warning : scheme.primary).withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.pending ? Icons.hourglass_top_rounded : Icons.check_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
