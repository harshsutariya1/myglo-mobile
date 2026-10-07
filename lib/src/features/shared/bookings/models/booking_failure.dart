import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/network_error.dart';

/// Rethrows [error] from a booking call. Refusals the server raises on
/// purpose (slot taken, outside the travel area…) become a [BookingFailure]
/// and are only logged locally; anything else (outages, bugs) is reported to
/// Sentry and rethrown unchanged, so connectivity errors still reach the
/// offline handling.
Never throwBookingError(Object error, StackTrace stackTrace, {required String tag, required String action}) {
  if (error is PostgrestException) {
    final failure = BookingFailure.from(error);
    if (failure.isExpected) {
      AppLogger.w('$action refused: ${failure.code.key}', tag: tag);
      Error.throwWithStackTrace(failure, stackTrace);
    }
  }
  AppLogger.e('$action failed', tag: tag, error: error, stackTrace: stackTrace);
  Error.throwWithStackTrace(error, stackTrace);
}

/// Why a booking action was refused. The booking RPCs raise these keys as
/// their error message (see the booking engine migration).
enum BookingFailureCode {
  slotUnavailable('slot_unavailable'),
  tooSoon('too_soon'),
  tooFarAhead('too_far_ahead'),
  priceChanged('price_changed'),
  invalidServices('invalid_services'),
  providerNotFound('provider_not_found'),
  providerNotAccepting('provider_not_accepting'),
  studioUnavailable('studio_unavailable'),
  mobileUnavailable('mobile_unavailable'),
  addressInvalid('address_invalid'),
  outsideServiceArea('outside_service_area'),
  serviceAreaUnavailable('service_area_unavailable'),
  serviceAreaNeedsLocation('service_area_needs_location'),
  phoneInvalid('phone_invalid'),
  notesTooLong('notes_too_long'),
  paymentMethodUnavailable('payment_method_unavailable'),
  clientOverlap('client_overlap'),
  tooManyBookings('too_many_bookings'),
  clientsOnly('clients_only'),
  providersOnly('providers_only'),
  notAuthenticated('not_authenticated'),
  bookingNotFound('booking_not_found'),
  bookingNotPending('booking_not_pending'),
  bookingRequestExpired('booking_request_expired'),
  bookingNotCancellable('booking_not_cancellable'),
  bookingNotConfirmed('booking_not_confirmed'),
  bookingNotStarted('booking_not_started'),
  paymentNotPending('payment_not_pending'),
  reasonRequired('reason_required'),
  lateCancellationUnconfirmed('late_cancellation_unconfirmed'),
  workingHoursOverlap('working_hours_overlap'),
  workingHoursInvalid('working_hours_invalid'),
  invalidRequest('invalid_request'),

  /// The request never reached the server (or its reply never came back).
  offline('offline'),
  unknown('unknown');

  const BookingFailureCode(this.key);

  final String key;

  static BookingFailureCode fromKey(String? key) {
    for (final code in values) {
      if (code.key == key) return code;
    }
    return unknown;
  }
}

/// A booking action the server refused, or that couldn't reach it, with copy
/// ready to show the user.
class BookingFailure implements Exception {
  const BookingFailure(this.code, {this.details = const {}});

  final BookingFailureCode code;

  /// Structured context some errors carry (fee, distance, notice period…).
  final Map<String, dynamic> details;

  /// Maps anything thrown by a booking call to a [BookingFailure].
  static BookingFailure from(Object error) {
    if (error is BookingFailure) return error;
    if (error is PostgrestException) {
      return BookingFailure(BookingFailureCode.fromKey(error.message), details: _parseDetails(error.details));
    }
    if (isConnectivityError(error)) return const BookingFailure(BookingFailureCode.offline);
    return const BookingFailure(BookingFailureCode.unknown);
  }

  static Map<String, dynamic> _parseDetails(Object? details) {
    if (details is Map<String, dynamic>) return details;
    if (details is String && details.startsWith('{')) {
      try {
        final decoded = jsonDecode(details);
        if (decoded is Map<String, dynamic>) return decoded;
      } on FormatException {
        // Plain-text detail; nothing structured to read.
      }
    }
    return const {};
  }

  /// Whether the failure was expected business logic rather than a bug or
  /// outage (so it shouldn't be reported to Sentry).
  bool get isExpected => code != BookingFailureCode.unknown && code != BookingFailureCode.invalidRequest;

  num? _number(String key) => details[key] is num ? details[key] as num : num.tryParse('${details[key]}');

  String get message => switch (code) {
        BookingFailureCode.slotUnavailable =>
          'Sorry, that time was just taken. Please pick another time.',
        BookingFailureCode.tooSoon => switch (_number('min_notice_minutes')) {
            final minutes? when minutes > 0 =>
              'This provider needs at least ${Formatters.duration(minutes.toInt())} notice. Please choose a later time.',
            _ => 'That time is too soon to book. Please choose a later time.',
          },
        BookingFailureCode.tooFarAhead => switch (_number('max_advance_days')) {
            final days? => "This provider takes bookings up to ${days.toInt()} days ahead. Please choose an earlier date.",
            null => "That date is too far ahead to book. Please choose an earlier date.",
          },
        BookingFailureCode.priceChanged =>
          'Prices for these services have just changed. Please review the updated total.',
        BookingFailureCode.invalidServices =>
          "One or more of these services isn't offered any more. Please review your selection.",
        BookingFailureCode.providerNotFound => "This provider isn't on Myglo any more.",
        BookingFailureCode.providerNotAccepting => "This provider isn't taking new bookings right now.",
        BookingFailureCode.studioUnavailable => "This provider isn't taking appointments at their studio right now.",
        BookingFailureCode.mobileUnavailable => "This provider doesn't travel to clients right now.",
        BookingFailureCode.addressInvalid =>
          "We couldn't use that address. Check the street, suburb, state and postcode.",
        BookingFailureCode.outsideServiceArea => switch ((_number('distance_km'), _number('radius_km'))) {
            (final distance?, final radius?) =>
              'That address is ${Formatters.distanceKm(distance.toDouble())} away, outside this provider\'s '
                  '${Formatters.distanceKm(radius.toDouble())} travel area.',
            _ => "That address is outside this provider's travel area.",
          },
        BookingFailureCode.serviceAreaUnavailable =>
          "This provider hasn't finished setting up their travel area yet. Please book at their studio.",
        BookingFailureCode.serviceAreaNeedsLocation =>
          'Set your business location before limiting how far you travel.',
        BookingFailureCode.phoneInvalid => 'Enter a contact number with 8 to 15 digits.',
        BookingFailureCode.notesTooLong => 'Your notes are too long. Please shorten them.',
        BookingFailureCode.paymentMethodUnavailable => 'That payment method isn\'t available yet. Please pay in cash.',
        BookingFailureCode.clientOverlap => 'You already have a booking at this time.',
        BookingFailureCode.tooManyBookings =>
          'You have the most upcoming bookings allowed with this provider. Cancel one to book another.',
        BookingFailureCode.clientsOnly => 'Only client accounts can make bookings.',
        BookingFailureCode.providersOnly => 'Only provider accounts can do that.',
        BookingFailureCode.notAuthenticated => 'Your session has expired. Please sign in again.',
        BookingFailureCode.bookingNotFound => "We couldn't find that booking.",
        BookingFailureCode.bookingNotPending => 'This request has already been answered.',
        BookingFailureCode.bookingRequestExpired => 'This request expired before it was answered.',
        BookingFailureCode.bookingNotCancellable => "This booking can't be cancelled any more.",
        BookingFailureCode.bookingNotConfirmed => 'Only confirmed bookings can be updated like this.',
        BookingFailureCode.bookingNotStarted => "You can do this once the appointment has started.",
        BookingFailureCode.paymentNotPending => 'This payment has already been recorded.',
        BookingFailureCode.reasonRequired => 'Please add a short reason for the client.',
        BookingFailureCode.lateCancellationUnconfirmed =>
          "It's now inside the cancellation window. Please review the late-cancellation terms.",
        BookingFailureCode.workingHoursOverlap => 'Two time ranges on the same day overlap. Please adjust them.',
        BookingFailureCode.workingHoursInvalid => 'Some of those hours aren\'t valid. Please check each day.',
        BookingFailureCode.offline =>
          "You appear to be offline. Check your connection and try again.",
        BookingFailureCode.invalidRequest || BookingFailureCode.unknown =>
          'Something went wrong. Please try again in a moment.',
      };

  @override
  String toString() => 'BookingFailure(${code.key}, $details)';
}
