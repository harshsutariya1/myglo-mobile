import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../shared/bookings/controllers/booking_controllers.dart';
import '../../../shared/bookings/models/booking_failure.dart';
import '../../../shared/bookings/models/booking_repository.dart';
import '../models/contacts_repository.dart';
import '../models/provider_contact.dart';

/// The signed-in provider's id, waiting for the profile (and only changing
/// if the signed-in provider does). Throws when the user isn't a provider.
Future<String> _providerId(Ref ref) async {
  final providerId = await ref.watch(
    userProfileProvider.selectAsync((p) => p?.isProvider == true ? p?.rawUser.id : null),
  );
  if (providerId == null) throw const BookingFailure(BookingFailureCode.providersOnly);
  return providerId;
}

/// How many clients have booked with the signed-in provider. Refetches
/// whenever one of their bookings changes, so a new client shows up live.
final providerContactCountProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(bookingChangesProvider);
  await _providerId(ref);
  return ref.watch(contactsRepositoryProvider).count();
});

/// One of the signed-in provider's clients, kept current as their bookings
/// change. Null when they've never booked with the provider.
final providerContactProvider = FutureProvider.autoDispose.family<ProviderContact?, String>((ref, clientId) async {
  ref.watch(bookingChangesProvider);
  await _providerId(ref);
  return ref.watch(contactsRepositoryProvider).get(clientId);
});

/// A loaded list of contacts, possibly with more to fetch.
class ContactPage {
  const ContactPage({
    required this.items,
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<ProviderContact> items;
  final bool hasMore;
  final bool loadingMore;

  /// The last attempt to load the next page failed (it can be retried).
  final bool loadMoreFailed;

  ContactPage copyWith({List<ProviderContact>? items, bool? hasMore, bool? loadingMore, bool? loadMoreFailed}) =>
      ContactPage(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );
}

/// The signed-in provider's contacts matching a search (empty for all of
/// them), most recent appointment first.
final contactsProvider =
    AsyncNotifierProvider.autoDispose.family<ContactsController, ContactPage, String>(ContactsController.new);

/// Pages through the provider's contacts for one search. Reloads whenever a
/// booking changes; later pages load on demand.
class ContactsController extends AsyncNotifier<ContactPage> {
  ContactsController(this.search);

  final String search;

  static int get pageSize => AppConfig.contactsPageSize;

  /// Most contacts reloaded at once when the list refreshes.
  static const int maxRefreshSize = 100;

  @override
  Future<ContactPage> build() async {
    ref.watch(bookingChangesProvider);
    await _providerId(ref);
    // A live refresh reloads as many as were already shown, so a list the
    // provider has scrolled through doesn't collapse to its first page.
    final shown = state.value?.items.length ?? 0;
    final limit = shown.clamp(pageSize, maxRefreshSize);
    final items = await ref.read(contactsRepositoryProvider).list(search: search, limit: limit);
    return ContactPage(items: items, hasMore: items.length == limit);
  }

  /// Appends the next page. Failures keep what's loaded, and scrolling won't
  /// retry on its own after one; pass [retry] when the provider asks to.
  Future<void> loadMore({bool retry = false}) async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore || current.items.isEmpty) return;
    if (current.loadMoreFailed && !retry) return;
    state = AsyncData(current.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final next = await ref.read(contactsRepositoryProvider).list(
            search: search,
            after: current.items.last,
            limit: pageSize,
          );
      if (!ref.mounted) return;
      final latest = state.value ?? current;
      final known = {for (final contact in latest.items) contact.clientId};
      state = AsyncData(ContactPage(
        items: [...latest.items, ...next.where((contact) => known.add(contact.clientId))],
        hasMore: next.length == pageSize,
      ));
    } catch (e, st) {
      // Unexpected failures were already reported by the repository.
      AppLogger.w('Loading more contacts failed', tag: 'Contacts', error: e, stackTrace: st);
      if (ref.mounted) {
        state = AsyncData((state.value ?? current).copyWith(loadingMore: false, loadMoreFailed: true));
      }
    }
  }
}

/// Every booking a client has made with the signed-in provider, latest
/// appointment first.
final clientBookingsProvider =
    AsyncNotifierProvider.autoDispose.family<ClientBookingsController, BookingPage, String>(
  ClientBookingsController.new,
);

/// Pages through one client's bookings with the signed-in provider. Reloads
/// whenever a booking changes; later pages load on demand.
class ClientBookingsController extends AsyncNotifier<BookingPage> {
  ClientBookingsController(this.clientId);

  final String clientId;

  static int get pageSize => AppConfig.clientBookingsPageSize;

  /// Most bookings reloaded at once when the list refreshes.
  static const int maxRefreshSize = 100;

  @override
  Future<BookingPage> build() async {
    ref.watch(bookingChangesProvider);
    final providerId = await _providerId(ref);
    final shown = state.value?.items.length ?? 0;
    final limit = shown.clamp(pageSize, maxRefreshSize);
    final items = await ref.read(bookingRepositoryProvider).listWithClient(
          providerId: providerId,
          clientId: clientId,
          limit: limit,
        );
    return BookingPage(items: items, hasMore: items.length == limit);
  }

  /// Appends the next page. Failures keep what's loaded, and scrolling won't
  /// retry on its own after one; pass [retry] when the provider asks to.
  Future<void> loadMore({bool retry = false}) async {
    final current = state.value;
    final providerId = ref.read(userProfileProvider).value?.rawUser.id;
    if (current == null || !current.hasMore || current.loadingMore || current.items.isEmpty || providerId == null) {
      return;
    }
    if (current.loadMoreFailed && !retry) return;
    state = AsyncData(current.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final next = await ref.read(bookingRepositoryProvider).listWithClient(
            providerId: providerId,
            clientId: clientId,
            after: current.items.last,
            limit: pageSize,
          );
      if (!ref.mounted) return;
      final latest = state.value ?? current;
      final known = {for (final booking in latest.items) booking.id};
      state = AsyncData(BookingPage(
        items: [...latest.items, ...next.where((booking) => known.add(booking.id))],
        hasMore: next.length == pageSize,
      ));
    } catch (e, st) {
      // Already reported by the repository.
      AppLogger.w("Loading more of a client's bookings failed", tag: 'Contacts', error: e, stackTrace: st);
      if (ref.mounted) {
        state = AsyncData((state.value ?? current).copyWith(loadingMore: false, loadMoreFailed: true));
      }
    }
  }
}
