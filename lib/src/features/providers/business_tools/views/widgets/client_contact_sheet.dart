import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/platform/contact_launcher.dart';
import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../../core/widgets/snackbar_utils.dart';
import '../../../../customers/provider_profile/views/widgets/section_states.dart';
import '../../../../shared/bookings/models/booking.dart';
import '../../../../shared/bookings/models/booking_enums.dart';
import '../../../../shared/bookings/models/booking_time.dart';
import '../../../../shared/bookings/views/widgets/booking_card.dart' show BookingDateTile, PersonAvatar;
import '../../../../shared/bookings/views/widgets/booking_pills.dart';
import '../../controllers/contacts_controllers.dart';
import '../../models/provider_contact.dart';

/// Opens [contact]'s card: who they are, their totals and every booking
/// they've made with the provider. Tapping a booking opens it in full.
Future<void> showClientContactSheet(BuildContext context, {required ProviderContact contact}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => ClientContactSheet(contact: contact),
  );
}

class ClientContactSheet extends ConsumerWidget {
  const ClientContactSheet({super.key, required this.contact});

  /// The contact as listed; replaced by fresher totals once they load.
  final ProviderContact contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final clientId = contact.clientId;
    // Kept live, so totals follow bookings that change while it's open.
    final current = ref.watch(providerContactProvider(clientId)).value ?? contact;
    final async = ref.watch(clientBookingsProvider(clientId));
    final page = async.value;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 1,
      snap: true,
      snapSizes: const [0.78],
      builder: (context, scrollController) => NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 300) ref.read(clientBookingsProvider(clientId).notifier).loadMore();
          return false;
        },
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              sliver: SliverToBoxAdapter(child: _ContactHeader(contact: current)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Booking history',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: scheme.onSurface),
                  ),
                ),
              ),
            ),
            if (page == null)
              SliverToBoxAdapter(
                child: switch (async) {
                  AsyncError(:final error) => SectionErrorView(
                      title: "Bookings didn't load",
                      message: describeLoadError(error, subject: "${current.displayName}'s bookings"),
                      onRetry: () => ref.invalidate(clientBookingsProvider(clientId)),
                    ),
                  _ => const _BookingTilesSkeleton(),
                },
              )
            else if (page.items.isEmpty)
              const SliverToBoxAdapter(
                child: SectionEmptyView(
                  icon: Icons.event_note_outlined,
                  title: 'No bookings to show',
                  message: "This client's bookings aren't available on your account any more.",
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: page.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final booking = page.items[index];
                    return ClientBookingTile(
                      booking: booking,
                      // Opens over the sheet; going back returns to it.
                      onTap: () => context.pushNamed(
                        AppRoute.providerBookingDetail.name,
                        pathParameters: {'bookingId': booking.id},
                      ),
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
                            onPressed: () => ref.read(clientBookingsProvider(clientId).notifier).loadMore(retry: true),
                            child: const Text("Couldn't load more. Try again"),
                          ),
                  ),
                ),
              ),
            SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom)),
          ],
        ),
      ),
    );
  }
}

/// Photo, name, how long they've been a client, ways to reach them, their
/// totals and contact details.
class _ContactHeader extends StatelessWidget {
  const _ContactHeader({required this.contact});

  final ProviderContact contact;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final since = BookingTime.wallClockOf(contact.firstBookedAt, contact.timeZone);
    final hasPhone = contact.phone.isNotEmpty;
    final email = contact.email;

    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: scheme.primary.withValues(alpha: 0.25), width: 3),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: PersonAvatar(name: contact.displayName, url: contact.avatarUrl, size: 76),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          contact.displayName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: scheme.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          'Client since ${Formatters.monthYear(since)}',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: muted),
        ),
        if (hasPhone || email != null) ...[
          const SizedBox(height: 18),
          _QuickActions(phone: hasPhone ? contact.phone : null, email: email),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _Figure(value: Formatters.compactCount(contact.completedCount), label: 'Visits')),
            const SizedBox(width: 10),
            Expanded(child: _Figure(value: Formatters.compactCount(contact.bookingCount), label: 'Bookings')),
            const SizedBox(width: 10),
            Expanded(child: _Figure(value: Formatters.audCents(contact.totalPaidCents), label: 'Paid', accent: true)),
          ],
        ),
        if (hasPhone || email != null) ...[
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                if (hasPhone)
                  _DetailRow(
                    icon: Icons.phone_outlined,
                    value: contact.phone,
                    caption: 'Phone · from their bookings',
                    copiedMessage: 'Phone number copied',
                  ),
                if (hasPhone && email != null)
                  Divider(height: 1, indent: 56, color: scheme.onSurface.withValues(alpha: 0.07)),
                if (email != null)
                  _DetailRow(
                    icon: Icons.mail_outline_rounded,
                    value: email,
                    caption: 'Email · shared on their profile',
                    copiedMessage: 'Email address copied',
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

Future<void> _copy(BuildContext context, String text, String message) async {
  await Clipboard.setData(ClipboardData(text: text));
  HapticFeedback.selectionClick();
  if (context.mounted) context.showAppSnackBar(message);
}

/// Call, message and email buttons. Email only appears when the client has
/// made theirs public. When no app on the device can handle one, the detail
/// is copied instead, so the provider still has it.
class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.phone, required this.email});

  final String? phone;
  final String? email;

  Future<void> _open(
    BuildContext context,
    Future<bool> Function() launch, {
    required String fallbackText,
    required String fallbackMessage,
  }) async {
    HapticFeedback.selectionClick();
    final opened = await launch();
    if (opened || !context.mounted) return;
    await _copy(context, fallbackText, fallbackMessage);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final launcher = ref.watch(contactLauncherProvider);
    final phone = this.phone;
    final email = this.email;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (phone != null) ...[
          _QuickAction(
            icon: Icons.call_rounded,
            label: 'Call',
            onTap: () => _open(
              context,
              () => launcher.call(phone),
              fallbackText: phone,
              fallbackMessage: "Couldn't open a phone app, so the number was copied",
            ),
          ),
          const SizedBox(width: 22),
          _QuickAction(
            icon: Icons.sms_outlined,
            label: 'Message',
            onTap: () => _open(
              context,
              () => launcher.message(phone),
              fallbackText: phone,
              fallbackMessage: "Couldn't open a messages app, so the number was copied",
            ),
          ),
        ],
        if (email != null) ...[
          if (phone != null) const SizedBox(width: 22),
          _QuickAction(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            onTap: () => _open(
              context,
              () => launcher.email(email),
              fallbackText: email,
              fallbackMessage: "Couldn't open a mail app, so the address was copied",
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.1),
                ),
                child: Icon(icon, size: 23, color: scheme.secondary),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: scheme.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A phone number or email address with a copy button.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.value,
    required this.caption,
    required this.copiedMessage,
  });

  final IconData icon;
  final String value;
  final String caption;
  final String copiedMessage;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.secondary),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: scheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.55)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy $value',
            onPressed: () => _copy(context, value, copiedMessage),
            icon: Icon(Icons.copy_rounded, size: 18, color: scheme.onSurface.withValues(alpha: 0.55)),
          ),
        ],
      ),
    );
  }
}

/// One of the totals under the client's name.
class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label, this.accent = false});

  final String value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: accent ? scheme.primary.withValues(alpha: 0.08) : scheme.onSurface.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: accent ? scheme.secondary : scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One booking in a client's history: when, what, how it went and what it
/// cost. Past and closed bookings are drawn quieter.
class ClientBookingTile extends StatelessWidget {
  const ClientBookingTile({super.key, required this.booking, required this.onTap});

  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final upcoming = booking.isUpcoming(DateTime.now());
    final start = booking.startsAtLocal;
    final otherYear = start.year != BookingTime.todayIn(booking.timeZone).year;
    final time = Formatters.timeRange(start, booking.endsAtLocal);
    final when = otherYear ? '${start.year} · $time' : time;

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: upcoming ? scheme.primary.withValues(alpha: 0.35) : scheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          label: '${booking.servicesSummary}, ${Formatters.dateShort(start)}${otherYear ? ' ${start.year}' : ''}, '
              '$time, ${booking.status.label}, ${Formatters.audCents(booking.totalCents)}',
          onTap: onTap,
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                BookingDateTile(date: start, muted: !upcoming, size: 58),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.servicesSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 13, color: muted),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              when,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: muted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          BookingStatusPill(status: booking.status, dense: true),
                          if (booking.status == BookingStatus.completed || booking.paymentStatus == PaymentStatus.paid)
                            PaymentStatusPill(
                              method: booking.paymentMethod,
                              status: booking.paymentStatus,
                              dense: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.audCents(booking.totalCents),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        // Bookings that didn't go ahead are quieter.
                        color: booking.status.isActive || booking.status == BookingStatus.completed
                            ? scheme.onSurface
                            : muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Icon(Icons.chevron_right_rounded, size: 20, color: scheme.onSurface.withValues(alpha: 0.3)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingTilesSkeleton extends StatelessWidget {
  const _BookingTilesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              const SkeletonBox(height: 96, borderRadius: 18),
            ],
          ],
        ),
      ),
    );
  }
}
