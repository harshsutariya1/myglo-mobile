import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../authentication/controllers/user_profile_provider.dart';
import '../models/availability_repository.dart';
import '../models/booking.dart';
import '../models/booking_failure.dart';
import '../models/booking_repository.dart';
import '../models/booking_settings.dart';
import '../models/working_hours.dart';

/// A provider's booking rules, kept live over realtime. Null when the
/// provider doesn't exist (or isn't a provider).
final bookingSettingsProvider =
    StreamProvider.autoDispose.family<ProviderBookingSettings?, String>((ref, providerId) {
  return ref.watch(availabilityRepositoryProvider).watchSettings(providerId);
});

/// A provider's published weekly opening hours. Refreshes with the
/// availability signal, so edits show up live.
final workingHoursProvider = FutureProvider.autoDispose.family<WeeklySchedule, String>((ref, providerId) async {
  await ref.watch(bookingSettingsProvider(providerId).future);
  return ref.watch(availabilityRepositoryProvider).getWorkingHours(providerId);
});

/// Ticks whenever one of the signed-in user's bookings changes (or the live
/// connection recovers), so booking screens refetch. Only bookings the user
/// is a party to are heard, as client or as provider.
final bookingChangesProvider = StreamProvider.autoDispose<int>((ref) {
  final viewer = ref.watch(
    userProfileProvider.select((p) => (id: p.value?.rawUser.id, isProvider: p.value?.isProvider ?? false)),
  );
  final userId = viewer.id;
  if (userId == null) return const Stream.empty();
  var tick = 0;
  return ref
      .watch(bookingRepositoryProvider)
      .watchChanges(party: viewer.isProvider ? BookingParty.provider : BookingParty.client, userId: userId)
      .map((_) => ++tick);
});

/// One booking, refreshed live. Null when it doesn't exist or isn't the
/// signed-in user's.
final bookingDetailsProvider = FutureProvider.autoDispose.family<Booking?, String>((ref, bookingId) {
  ref.watch(bookingChangesProvider);
  return ref.watch(bookingRepositoryProvider).getBooking(bookingId);
});

/// Which list of bookings: whose side, and which slice.
typedef BookingListKey = ({BookingParty party, BookingListScope scope});

/// A loaded list of bookings, possibly with more to fetch.
class BookingPage {
  const BookingPage({
    required this.items,
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<Booking> items;
  final bool hasMore;
  final bool loadingMore;

  /// The last attempt to load the next page failed (it can be retried).
  final bool loadMoreFailed;

  BookingPage copyWith({List<Booking>? items, bool? hasMore, bool? loadingMore, bool? loadMoreFailed}) => BookingPage(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );
}

final bookingListProvider =
    AsyncNotifierProvider.autoDispose.family<BookingListController, BookingPage, BookingListKey>(
  BookingListController.new,
);

/// The signed-in user's bookings for one [BookingListKey]. Reloads whenever
/// a booking changes; later pages load on demand.
class BookingListController extends AsyncNotifier<BookingPage> {
  BookingListController(this.key);

  final BookingListKey key;

  static const int pageSize = 20;

  /// Most bookings reloaded at once when the list refreshes.
  static const int maxRefreshSize = 100;

  @override
  Future<BookingPage> build() async {
    ref.watch(bookingChangesProvider);
    final userId = ref.watch(userProfileProvider.select((p) => p.value?.rawUser.id));
    if (userId == null) return const BookingPage(items: [], hasMore: false);
    // A live refresh reloads as many as were already shown, so a list the
    // user has scrolled through doesn't collapse to its first page.
    final shown = state.value?.items.length ?? 0;
    final limit = shown.clamp(pageSize, maxRefreshSize);
    final items = await ref.read(bookingRepositoryProvider).listBookings(
          party: key.party,
          userId: userId,
          scope: key.scope,
          limit: limit,
        );
    return BookingPage(items: items, hasMore: items.length == limit);
  }

  /// Appends the next page. Failures keep what's loaded.
  Future<void> loadMore() async {
    final current = state.value;
    final userId = ref.read(userProfileProvider).value?.rawUser.id;
    if (current == null || !current.hasMore || current.loadingMore || userId == null || current.items.isEmpty) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final next = await ref.read(bookingRepositoryProvider).listBookings(
            party: key.party,
            userId: userId,
            scope: key.scope,
            after: current.items.last,
            limit: pageSize,
          );
      if (!ref.mounted) return;
      final latest = state.value ?? current;
      state = AsyncData(BookingPage(
        items: [...latest.items, ...next.where((b) => latest.items.every((existing) => existing.id != b.id))],
        hasMore: next.length == pageSize,
      ));
    } catch (e, st) {
      AppLogger.w('Loading more bookings failed', tag: 'BookingList', error: e, stackTrace: st);
      if (ref.mounted) {
        state = AsyncData((state.value ?? current).copyWith(loadingMore: false, loadMoreFailed: true));
      }
    }
  }
}

/// Booking lifecycle actions. Each returns the updated booking or throws a
/// [BookingFailure] whose message can be shown as is.
final bookingActionsProvider = Provider<BookingActions>(BookingActions.new);

class BookingActions {
  BookingActions(this._ref);

  final Ref _ref;

  BookingRepository get _repository => _ref.read(bookingRepositoryProvider);

  Future<Booking> accept(String bookingId) => _run(bookingId, () => _repository.respondToRequest(bookingId, accept: true));

  Future<Booking> decline(String bookingId, {String? reason}) =>
      _run(bookingId, () => _repository.respondToRequest(bookingId, accept: false, reason: reason));

  Future<Booking> cancel(String bookingId, {String? reason, bool acceptLateCancellation = false}) => _run(
        bookingId,
        () => _repository.cancel(bookingId, reason: reason, acceptLateCancellation: acceptLateCancellation),
      );

  Future<Booking> complete(String bookingId, {required bool paymentReceived}) =>
      _run(bookingId, () => _repository.complete(bookingId, paymentReceived: paymentReceived));

  Future<Booking> markNoShow(String bookingId) => _run(bookingId, () => _repository.markNoShow(bookingId));

  Future<Booking> recordCashPayment(String bookingId) =>
      _run(bookingId, () => _repository.recordCashPayment(bookingId));

  Future<Booking> _run(String bookingId, Future<Booking> Function() action) async {
    try {
      final booking = await action();
      // Realtime refreshes these too; invalidating makes it immediate.
      _ref.invalidate(bookingDetailsProvider(bookingId));
      _ref.invalidate(bookingListProvider);
      return booking;
    } catch (e) {
      throw BookingFailure.from(e);
    }
  }
}
