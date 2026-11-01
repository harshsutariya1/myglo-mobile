import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/payments/payment_sheet_gateway.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/bookings/models/booking.dart';
import '../../../shared/bookings/models/booking_enums.dart';
import '../../../shared/bookings/models/booking_failure.dart';
import '../../../shared/bookings/models/booking_repository.dart';
import '../models/booking_draft.dart';
import '../models/card_checkout_repository.dart';
import '../models/service_selection.dart';
import 'booking_draft_controller.dart';

/// Where placing the booking is up to.
enum CheckoutStage {
  idle,

  /// Creating the booking (and, for card, the payment).
  placing,

  /// Stripe's payment sheet is open.
  paying,

  /// Paid; waiting for the payment to reach the booking.
  confirming,
}

class CheckoutState {
  const CheckoutState({this.stage = CheckoutStage.idle, this.failure, this.paymentMessage});

  final CheckoutStage stage;

  /// Why the booking couldn't be placed (shown by the payment screen).
  final BookingFailure? failure;

  /// Why the last card payment didn't go through (a declined card…), shown
  /// beside the pay button so the client can try again.
  final String? paymentMessage;

  bool get busy => stage != CheckoutStage.idle;
}

/// Places the booking for one provider's funnel.
final checkoutControllerProvider = NotifierProvider.autoDispose.family<CheckoutController, CheckoutState, String>(
  CheckoutController.new,
);

/// Places a booking and, when it's paid in the app, takes the payment.
///
/// A card booking is created first (the server holds the time while the
/// client pays), then paid in Stripe's payment sheet. Retrying after the
/// client closes the sheet or a card is declined reuses the same booking and
/// PaymentIntent, so nothing is charged twice. Leaving the funnel with an
/// unpaid checkout gives it up, freeing the time straight away.
class CheckoutController extends Notifier<CheckoutState> {
  CheckoutController(this.providerId);

  final String providerId;

  static const _tag = 'Checkout';
  static const Duration _pollInterval = Duration(milliseconds: 1500);

  /// An unpaid checkout this funnel created, given up when the funnel closes
  /// (through the repository that created it: ref can't be used then).
  String? _openCheckoutId;
  CardCheckoutRepository? _openCheckoutRepository;

  @override
  CheckoutState build() {
    ref.onDispose(() {
      final id = _openCheckoutId;
      final repository = _openCheckoutRepository;
      if (id == null || repository == null) return;
      unawaited(
        repository.abandon(id).catchError((Object e) {
          // The hold runs out on its own a few minutes later.
          AppLogger.w('Could not give up checkout $id', tag: _tag, error: e);
        }),
      );
    });
    return const CheckoutState();
  }

  BookingRepository get _bookings => ref.read(bookingRepositoryProvider);
  CardCheckoutRepository get _checkout => ref.read(cardCheckoutRepositoryProvider);

  /// Creates the booking and, for card, takes the payment. Returns the
  /// booking (possibly still confirming its payment), or null with the
  /// reason in the state. Ignored while a submission is running.
  Future<Booking?> submit({
    required ServiceSelection selection,
    required BookingDraft draft,
    required String phone,
  }) async {
    if (state.busy) return null;
    final slot = draft.slot;
    final location = draft.locationType;
    if (selection.isEmpty || slot == null || location == null || !draft.hasLocation) {
      state = const CheckoutState(failure: BookingFailure(BookingFailureCode.invalidRequest));
      return null;
    }

    state = const CheckoutState(stage: CheckoutStage.placing);
    try {
      var booking = await _bookings.createBooking(_request(selection, draft, phone));
      if (booking.status == BookingStatus.checkoutExpired) {
        // This attempt's checkout ran out (or was given up) earlier: start a
        // new one with the same choices.
        final renewed = _renewAttempt();
        booking = await _bookings.createBooking(_request(selection, renewed, phone));
      }
      if (!ref.mounted) return null;
      if (booking.paymentMethod.isCash) {
        state = const CheckoutState();
        return booking;
      }
      return await _payByCard(booking, totalCents: selection.totalCents);
    } catch (e) {
      final failure = BookingFailure.from(e);
      if (failure.code == BookingFailureCode.checkoutExpired) {
        _openCheckoutId = null;
        _renewAttempt();
      }
      if (ref.mounted) state = CheckoutState(failure: failure);
      return null;
    }
  }

  Future<Booking?> _payByCard(Booking booking, {required int totalCents}) async {
    if (booking.status != BookingStatus.awaitingPayment) {
      // Paid on an earlier try.
      _openCheckoutId = null;
      state = const CheckoutState();
      return booking;
    }
    _openCheckoutId = booking.id;
    _openCheckoutRepository = _checkout;

    final session = await _checkout.start(booking.id);
    if (!ref.mounted) return null;
    if (!session.alreadyPaid) {
      state = const CheckoutState(stage: CheckoutStage.paying);
      final result = await ref
          .read(paymentSheetGatewayProvider)
          .present(
            PaymentSheetRequest(
              clientSecret: session.clientSecret!,
              livemode: session.livemode,
              primaryButtonLabel: session.isHold
                  ? 'Hold ${Formatters.audCents(totalCents)}'
                  : 'Pay ${Formatters.audCents(totalCents)}',
            ),
          );
      if (!ref.mounted) return null;
      switch (result.outcome) {
        case PaymentSheetOutcome.canceled:
          state = const CheckoutState();
          return null;
        case PaymentSheetOutcome.failed:
          AppLogger.w('Card payment for ${booking.id} failed: ${result.code ?? 'no code'}', tag: _tag);
          state = CheckoutState(
            paymentMessage: result.message ?? "Your payment didn't go through. Please try again or use another card.",
          );
          return null;
        case PaymentSheetOutcome.completed:
          break;
      }
    }

    _openCheckoutId = null;
    state = const CheckoutState(stage: CheckoutStage.confirming);
    final confirmed = await _awaitPaymentOutcome(booking);
    if (ref.mounted) state = const CheckoutState();
    return confirmed;
  }

  /// Stripe tells the server through a webhook, usually within a second or
  /// two; the sync call also asks the server to check Stripe directly. After
  /// [AppConfig.paymentConfirmationTimeout] the booking is returned as it
  /// is, and the confirmation screen keeps updating live.
  Future<Booking> _awaitPaymentOutcome(Booking booking) async {
    final deadline = DateTime.now().add(AppConfig.paymentConfirmationTimeout);
    var latest = booking;
    try {
      await _checkout.sync(booking.id);
    } catch (e) {
      AppLogger.w('Payment sync for ${booking.id} failed; waiting for the webhook', tag: _tag, error: e);
    }
    while (ref.mounted) {
      try {
        latest = await _bookings.getBooking(booking.id) ?? latest;
      } catch (e) {
        AppLogger.w('Reloading ${booking.id} after payment failed', tag: _tag, error: e);
      }
      if (latest.status != BookingStatus.awaitingPayment || DateTime.now().isAfter(deadline)) break;
      await Future<void>.delayed(_pollInterval);
    }
    return latest;
  }

  BookingDraft _renewAttempt() {
    final draft = ref.read(bookingDraftProvider(providerId).notifier);
    draft.renewAttempt();
    return ref.read(bookingDraftProvider(providerId));
  }

  BookingRequest _request(ServiceSelection selection, BookingDraft draft, String phone) {
    final location = draft.locationType!;
    return BookingRequest(
      bookingId: draft.attemptId,
      providerId: providerId,
      serviceIds: [for (final service in selection.services) service.id],
      startsAt: draft.slot!.startsAt,
      locationType: location,
      phone: phone,
      expectedTotalCents: selection.totalCents,
      paymentMethod: draft.paymentMethod,
      address: location == BookingLocationType.client ? draft.address : null,
      point: location == BookingLocationType.client ? draft.verifiedPoint : null,
      accessNotes: draft.accessNotes,
      notes: draft.notes,
    );
  }

  /// Clears a shown error.
  void reset() {
    if (!state.busy) state = const CheckoutState();
  }
}
