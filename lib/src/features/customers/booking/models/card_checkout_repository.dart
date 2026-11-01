import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../shared/authentication/models/auth_repository.dart';
import '../../../shared/bookings/models/booking_failure.dart';

final cardCheckoutRepositoryProvider = Provider<CardCheckoutRepository>(
  (ref) => CardCheckoutRepository(ref.watch(supabaseClientProvider)),
);

/// What the payment sheet needs for one booking, or word that it's paid
/// already (the app missed Stripe's answer last time).
class CardCheckoutSession {
  const CardCheckoutSession({
    this.clientSecret,
    this.livemode = false,
    this.alreadyPaid = false,
    this.isHold = false,
    this.holdExpiresAt,
  });

  factory CardCheckoutSession.fromJson(Map<String, dynamic> json) => CardCheckoutSession(
    clientSecret: json['client_secret'] as String?,
    livemode: json['livemode'] == true,
    alreadyPaid: json['paid'] == true,
    isHold: json['capture_method'] == 'manual',
    holdExpiresAt: DateTime.tryParse('${json['hold_expires_at']}'),
  );

  final String? clientSecret;
  final bool livemode;
  final bool alreadyPaid;

  /// The card is held, not charged, until the provider accepts.
  final bool isHold;

  /// Until when the time is held for the client while they pay.
  final DateTime? holdExpiresAt;
}

/// Card payments for a client's booking. Stripe calls happen in the
/// `payments` Edge Function; the database decides who may pay for what, and
/// how much.
class CardCheckoutRepository {
  CardCheckoutRepository(this._client);

  final SupabaseClient _client;

  static const _tag = 'CardCheckout';

  /// The PaymentIntent for [bookingId] (created on first call; the same one
  /// on every retry).
  Future<CardCheckoutSession> start(String bookingId) async =>
      CardCheckoutSession.fromJson(await _payments('checkout', bookingId));

  /// Asks the server to check Stripe now, for when the webhook is slow.
  Future<void> sync(String bookingId) async {
    await _payments('sync', bookingId);
  }

  /// Gives up on the unpaid checkout, freeing the time at once.
  Future<void> abandon(String bookingId) async {
    try {
      await _client.rpc('abandon_checkout', params: {'p_booking_id': bookingId});
      AppLogger.i('Checkout $bookingId abandoned', tag: _tag);
    } catch (e, st) {
      throwBookingError(e, st, tag: _tag, action: 'Abandoning checkout $bookingId');
    }
  }

  Future<Map<String, dynamic>> _payments(String action, String bookingId) async {
    final sw = Stopwatch()..start();
    try {
      final response = await _client.functions.invoke('payments', body: {'action': action, 'booking_id': bookingId});
      sw.stop();
      AppLogger.api('fn.payments', endpoint: '$action $bookingId', duration: sw.elapsed);
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e, st) {
      throwBookingError(e, st, tag: _tag, action: 'payments.$action for $bookingId');
    }
  }
}
