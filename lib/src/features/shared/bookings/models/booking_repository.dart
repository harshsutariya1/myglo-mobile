import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/location/geo_point.dart';
import '../../../../core/realtime/postgres_changes.dart';
import '../../../../core/utils/app_logger.dart';
import '../../authentication/models/auth_repository.dart';
import 'booking.dart';
import 'booking_enums.dart';
import 'booking_failure.dart';
import 'client_address.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(ref.watch(supabaseClientProvider));
});

/// Which side of a booking the signed-in user is on.
enum BookingParty {
  client('client_id'),
  provider('provider_id');

  const BookingParty(this.column);

  final String column;
}

/// Slices of a user's bookings.
enum BookingListScope {
  /// Active bookings (requests and confirmed) that haven't finished, soonest
  /// first.
  upcoming,

  /// Confirmed bookings that haven't finished, soonest first.
  confirmed,

  /// Requests waiting for the provider, soonest first.
  requests,

  /// Finished or closed bookings, most recent first.
  past;

  /// Whether the list runs from the most recent backwards.
  bool get newestFirst => this == past;
}

/// Everything `create_booking` needs. Prices and lengths are always taken
/// from the database; [expectedTotalCents] only lets the server refuse if the
/// client was shown a stale total.
class BookingRequest {
  const BookingRequest({
    required this.bookingId,
    required this.providerId,
    required this.serviceIds,
    required this.startsAt,
    required this.locationType,
    required this.phone,
    required this.expectedTotalCents,
    this.paymentMethod = PaymentMethod.cash,
    this.address,
    this.point,
    this.accessNotes,
    this.notes,
  });

  /// Client-generated id that makes the request idempotent.
  final String bookingId;
  final String providerId;
  final List<String> serviceIds;
  final DateTime startsAt;
  final BookingLocationType locationType;
  final String phone;
  final int expectedTotalCents;
  final PaymentMethod paymentMethod;
  final ClientAddress? address;
  final GeoPoint? point;
  final String? accessNotes;
  final String? notes;

  Map<String, dynamic> toRpcParams() => {
        'p_booking_id': bookingId,
        'p_provider_id': providerId,
        'p_service_ids': serviceIds,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_location_type': locationType.wireName,
        'p_client_phone': phone,
        'p_expected_total_cents': expectedTotalCents,
        'p_payment_method': paymentMethod.wireName,
        'p_address': locationType == BookingLocationType.client ? address?.toJson() : null,
        'p_latitude': locationType == BookingLocationType.client ? point?.latitude : null,
        'p_longitude': locationType == BookingLocationType.client ? point?.longitude : null,
        'p_access_notes': _blankToNull(accessNotes),
        'p_client_notes': _blankToNull(notes),
      };

  static String? _blankToNull(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

/// Bookings for both parties. Reads come from the `booking_details` view
/// (row level security limits it to the caller's bookings); every write goes
/// through an RPC that validates it server-side.
class BookingRepository {
  BookingRepository(this._client);

  final SupabaseClient _client;

  static const _view = 'booking_details';
  static const _tag = 'BookingRepository';

  /// Creates the booking atomically. Safe to retry with the same
  /// [BookingRequest.bookingId]: a repeat returns the original booking.
  Future<Booking> createBooking(BookingRequest request) async {
    final sw = Stopwatch()..start();
    try {
      final row = await _client.rpc('create_booking', params: request.toRpcParams());
      sw.stop();
      AppLogger.api('rpc.create_booking', endpoint: 'provider=${request.providerId}', duration: sw.elapsed);
      final id = (row as Map)['id'] as String;
      AppLogger.i('Booking $id created (${row['status']})', tag: _tag);
      return await _requireBooking(id);
    } catch (e, st) {
      throwBookingError(e, st, tag: _tag, action: 'Creating a booking with ${request.providerId}');
    }
  }

  /// One booking, or null when it doesn't exist or isn't the caller's.
  Future<Booking?> getBooking(String id) async {
    final sw = Stopwatch()..start();
    try {
      final row = await _client.from(_view).select().eq('id', id).maybeSingle();
      sw.stop();
      AppLogger.api('$_view.select(single)', endpoint: 'id=$id', duration: sw.elapsed);
      return row == null ? null : Booking.fromJson(row);
    } catch (e, st) {
      AppLogger.e('Failed to load booking $id', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  /// A page of [userId]'s bookings as [party]. Lists are keyset paginated:
  /// pass the last booking already shown as [after] for the next page.
  Future<List<Booking>> listBookings({
    required BookingParty party,
    required String userId,
    required BookingListScope scope,
    Booking? after,
    int limit = 20,
    DateTime? now,
  }) async {
    // Timestamps contain reserved characters (`.` `:`), so they're quoted.
    final nowIso = (now ?? DateTime.now()).toUtc().toIso8601String();
    final sw = Stopwatch()..start();
    try {
      var query = _client.from(_view).select().eq(party.column, userId);
      switch (scope) {
        case BookingListScope.upcoming:
          query = query.inFilter('status', const ['pending', 'confirmed']).gte('ends_at', nowIso);
        case BookingListScope.confirmed:
          query = query.eq('status', 'confirmed').gte('ends_at', nowIso);
        case BookingListScope.requests:
          query = query.eq('status', 'pending');
        case BookingListScope.past:
          query = query.or('ends_at.lt."$nowIso",status.not.in.(pending,confirmed)');
      }
      if (after != null) {
        // (starts_at, id) keeps the order total when start times repeat.
        final op = scope.newestFirst ? 'lt' : 'gt';
        final startsAt = after.startsAt.toUtc().toIso8601String();
        query = query.or('starts_at.$op."$startsAt",and(starts_at.eq."$startsAt",id.$op.${after.id})');
      }
      final ascending = !scope.newestFirst;
      final List<dynamic> rows =
          await query.order('starts_at', ascending: ascending).order('id', ascending: ascending).limit(limit);
      sw.stop();
      final bookings = rows.map((row) => Booking.fromJson(Map<String, dynamic>.from(row as Map))).toList();
      AppLogger.api('$_view.select(${party.name}/${scope.name})', count: bookings.length, duration: sw.elapsed);
      return bookings;
    } catch (e, st) {
      AppLogger.e('Failed to load ${scope.name} bookings', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  /// [providerId]'s active bookings overlapping [start, end), e.g. to warn
  /// before blocking that time off.
  Future<List<Booking>> activeBookingsBetween({
    required String providerId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final rows = await _client
          .from(_view)
          .select()
          .eq('provider_id', providerId)
          .inFilter('status', const ['pending', 'confirmed'])
          .lt('starts_at', end.toUtc().toIso8601String())
          .gt('ends_at', start.toUtc().toIso8601String())
          .order('starts_at')
          .limit(100);
      return [for (final row in rows) Booking.fromJson(row)];
    } catch (e, st) {
      AppLogger.e('Failed to check bookings in a time range', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Distinct addresses from the client's recent mobile bookings, newest
  /// first, so they can be reused.
  Future<List<ClientAddress>> recentAddresses(String clientId, {int limit = 5}) async {
    try {
      final rows = await _client
          .from(_view)
          .select('address')
          .eq('client_id', clientId)
          .eq('location_type', BookingLocationType.client.wireName)
          .order('created_at', ascending: false)
          .limit(30);
      final seen = <ClientAddress>{};
      for (final row in rows) {
        final json = row['address'];
        if (json is Map) {
          final address = ClientAddress.fromJson(Map<String, dynamic>.from(json));
          if (address.isComplete) seen.add(address);
        }
        if (seen.length >= limit) break;
      }
      return seen.toList();
    } catch (e, st) {
      AppLogger.e('Failed to load recent addresses', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Provider accepts or declines a pending request.
  Future<Booking> respondToRequest(String id, {required bool accept, String? reason}) => _act(
        'respond_to_booking_request',
        id,
        {'p_booking_id': id, 'p_accept': accept, 'p_reason': reason},
      );

  /// Cancels as whichever party the caller is. Clients inside the provider's
  /// window must pass [acceptLateCancellation] after seeing the terms.
  Future<Booking> cancel(String id, {String? reason, bool acceptLateCancellation = false}) => _act(
        'cancel_booking',
        id,
        {'p_booking_id': id, 'p_reason': reason, 'p_accept_late_cancellation': acceptLateCancellation},
      );

  /// Provider marks a started appointment as done.
  Future<Booking> complete(String id, {required bool paymentReceived}) =>
      _act('complete_booking', id, {'p_booking_id': id, 'p_payment_received': paymentReceived});

  Future<Booking> markNoShow(String id) => _act('mark_booking_no_show', id, {'p_booking_id': id});

  Future<Booking> recordCashPayment(String id) => _act('record_cash_payment', id, {'p_booking_id': id});

  /// Changes to [userId]'s bookings as [party], live.
  Stream<RealtimeChange> watchChanges({required BookingParty party, required String userId}) {
    return watchPostgresChanges(
      _client,
      table: 'bookings',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: party.column, value: userId),
    );
  }

  Future<Booking> _act(String fn, String id, Map<String, dynamic> params) async {
    final sw = Stopwatch()..start();
    try {
      await _client.rpc(fn, params: params);
      sw.stop();
      AppLogger.api('rpc.$fn', endpoint: 'id=$id', duration: sw.elapsed);
      return await _requireBooking(id);
    } catch (e, st) {
      throwBookingError(e, st, tag: _tag, action: '$fn on $id');
    }
  }

  Future<Booking> _requireBooking(String id) async {
    final booking = await getBooking(id);
    if (booking == null) throw const BookingFailure(BookingFailureCode.bookingNotFound);
    return booking;
  }
}
