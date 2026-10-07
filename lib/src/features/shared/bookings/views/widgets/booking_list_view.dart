import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../customers/provider_profile/views/widgets/section_states.dart';
import '../../controllers/booking_controllers.dart';
import '../../models/booking.dart';
import '../../models/booking_repository.dart';
import '../../models/booking_time.dart';
import 'booking_card.dart';

/// Builds the card for one booking (so lists can add actions).
typedef BookingCardBuilder = Widget Function(BuildContext context, Booking booking);

/// How a booking list is split under headings.
enum BookingListGrouping {
  none,

  /// `TODAY`, `TOMORROW`, `WEDNESDAY 8 OCTOBER`… (provider-local days).
  day,

  /// `OCTOBER 2026`…
  month,
}

/// A live list of the signed-in user's bookings for [listKey], as slivers:
/// skeleton while loading, inline error with retry, empty state, cards under
/// optional headings, and paging at the end.
class BookingListSliver extends ConsumerWidget {
  const BookingListSliver({
    super.key,
    required this.listKey,
    required this.cardBuilder,
    required this.empty,
    this.grouping,
  });

  final BookingListKey listKey;
  final BookingCardBuilder cardBuilder;
  final Widget empty;

  /// Defaults to months for past bookings and none otherwise.
  final BookingListGrouping? grouping;

  static String _dayHeader(Booking booking) {
    final today = BookingTime.todayIn(booking.timeZone);
    final day = BookingTime.dateOf(booking.startsAtLocal);
    final days = day.difference(today).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return Formatters.dateLong(day, currentYear: today.year);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookingListProvider(listKey));
    final page = async.value;

    if (page == null) {
      if (async case AsyncError(:final error)) {
        return SliverToBoxAdapter(
          child: SectionErrorView(
            title: "Bookings didn't load",
            message: describeLoadError(error, subject: 'your bookings'),
            onRetry: () => ref.invalidate(bookingListProvider(listKey)),
          ),
        );
      }
      return SliverList.separated(
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, _) => const Shimmer(child: BookingCardSkeleton()),
      );
    }

    if (page.items.isEmpty) return SliverToBoxAdapter(child: empty);

    final grouping =
        this.grouping ?? (listKey.scope == BookingListScope.past ? BookingListGrouping.month : BookingListGrouping.none);
    final rows = <Widget>[];
    String? currentHeader;
    for (final booking in page.items) {
      final header = switch (grouping) {
        BookingListGrouping.none => null,
        BookingListGrouping.day => _dayHeader(booking),
        BookingListGrouping.month => Formatters.monthYear(booking.startsAtLocal),
      };
      if (header != null && header != currentHeader) {
        currentHeader = header;
        rows.add(_GroupHeader(label: header, first: rows.isEmpty));
      }
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: KeyedSubtree(key: ValueKey(booking.id), child: cardBuilder(context, booking)),
      ));
    }
    if (page.hasMore) {
      void loadMore() => ref.read(bookingListProvider(listKey).notifier).loadMore();
      rows.add(page.loadMoreFailed ? _LoadMoreFailed(onRetry: loadMore) : _LoadMore(onVisible: loadMore));
    }

    return SliverList.list(children: rows);
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.first});

  final String label;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 10, bottom: 12, left: 4),
      child: Semantics(
        header: true,
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: context.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

/// Triggers [onVisible] once when scrolled into view.
class _LoadMore extends StatefulWidget {
  const _LoadMore({required this.onVisible});

  final VoidCallback onVisible;

  @override
  State<_LoadMore> createState() => _LoadMoreState();
}

class _LoadMoreState extends State<_LoadMore> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisible();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: context.colorScheme.primary),
        ),
      ),
    );
  }
}

class _LoadMoreFailed extends StatelessWidget {
  const _LoadMoreFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(
            "Couldn't load more bookings.",
            style: TextStyle(fontSize: 13.5, color: scheme.onSurface.withValues(alpha: 0.6)),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
            style: TextButton.styleFrom(
              foregroundColor: scheme.onSurface,
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Friendly empty state with an optional call to action.
class BookingsEmptyState extends StatelessWidget {
  const BookingsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      children: [
        SectionEmptyView(icon: icon, title: title, message: message),
        if (actionLabel != null && onAction != null)
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.onSurface,
              foregroundColor: scheme.surface,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}
