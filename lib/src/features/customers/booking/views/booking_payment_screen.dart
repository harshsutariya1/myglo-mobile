import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/remote_app_config.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../../providers/provider_profiles/controllers/provider_services_controller.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../shared/bookings/controllers/booking_controllers.dart';
import '../../../shared/bookings/models/booking_enums.dart';
import '../../../shared/bookings/models/booking_failure.dart';
import '../../../shared/bookings/models/booking_settings.dart';
import '../../../shared/bookings/models/booking_terms.dart';
import '../../../shared/bookings/views/widgets/booking_summary.dart';
import '../../provider_profile/controllers/public_provider_profile_controller.dart';
import '../../provider_profile/views/widgets/provider_profile_header.dart';
import '../controllers/availability_controller.dart';
import '../controllers/booking_draft_controller.dart';
import '../controllers/checkout_controller.dart';
import '../controllers/service_selection_controller.dart';
import 'booking_flow_navigation.dart';
import 'widgets/booking_flow_scaffold.dart';
import 'widgets/payment_option_tile.dart';

/// Which ways to pay this booking can use, from the provider's settings and
/// how far ahead it is.
class PaymentChoices {
  const PaymentChoices({required this.cash, required this.card, required this.cardTooFarAhead});

  factory PaymentChoices.of(
    ProviderBookingSettings? settings, {
    required DateTime? startsAt,
    required int cardMaxAdvanceDays,
    required DateTime now,
  }) {
    // Until settings load, offer cash only: the server decides either way.
    if (settings == null) return const PaymentChoices(cash: true, card: false, cardTooFarAhead: false);
    final tooFar = startsAt != null && startsAt.isAfter(now.add(Duration(days: cardMaxAdvanceDays)));
    return PaymentChoices(
      cash: settings.takesCash,
      card: settings.takesCard && !tooFar,
      cardTooFarAhead: settings.takesCard && tooFar,
    );
  }

  /// The provider takes cash at the appointment.
  final bool cash;

  /// The client can pay in the app for this booking.
  final bool card;

  /// The provider takes card, but not this far ahead.
  final bool cardTooFarAhead;

  bool allows(PaymentMethod method) => method.isCash ? cash : method == PaymentMethod.card && card;

  /// The method to fall back on when [method] can't be used.
  PaymentMethod? fallbackFor(PaymentMethod method) {
    if (allows(method)) return null;
    if (card) return PaymentMethod.card;
    if (cash) return PaymentMethod.cash;
    return null;
  }
}

/// Step 5: choose how to pay and place the booking.
///
/// Clients pay in the app (card, Apple Pay or Google Pay through Stripe's
/// payment sheet) or in cash at the appointment, as the provider allows.
/// A cash booking is always a request with no fees; a booking paid in the
/// app follows the provider's own rules: charged now for instant bookings,
/// or held on the card until a request is accepted (see [BookingTerms]).
/// Placing the booking re-checks everything server-side in one transaction
/// (the time, prices, travel area); if something changed, the client is taken
/// straight to the step that needs attention with their other choices intact.
class BookingPaymentScreen extends ConsumerWidget {
  const BookingPaymentScreen({super.key, required this.providerId});

  final String providerId;

  /// Wallet shown for this platform.
  static PaymentMethod walletFor(TargetPlatform platform) =>
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
      ? PaymentMethod.applePay
      : PaymentMethod.googlePay;

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final draft = ref.read(bookingDraftProvider(providerId));
    final selection = ref.read(serviceSelectionProvider(providerId));
    // The review step stores the confirmed number; the profile is a fallback
    // (the server validates it either way).
    final phone = draft.phone ?? (await ref.read(userProfileProvider.future))?.profile.phoneNumber ?? '';
    if (!context.mounted) return;
    final booking = await ref
        .read(checkoutControllerProvider(providerId).notifier)
        .submit(selection: selection, draft: draft, phone: phone);
    if (!context.mounted) return;
    if (booking != null) {
      HapticFeedback.heavyImpact();
      context.goNamed(AppRoute.bookingConfirmed.name, pathParameters: {'bookingId': booking.id}, extra: booking);
      return;
    }
    final failure = ref.read(checkoutControllerProvider(providerId)).failure;
    if (failure != null) await _handleFailure(context, ref, failure);
  }

  Future<void> _handleFailure(BuildContext context, WidgetRef ref, BookingFailure failure) async {
    HapticFeedback.heavyImpact();
    final draftController = ref.read(bookingDraftProvider(providerId).notifier);
    switch (failure.code) {
      case BookingFailureCode.slotUnavailable || BookingFailureCode.tooSoon || BookingFailureCode.tooFarAhead:
        final go = await _explain(
          context,
          icon: Icons.event_busy_rounded,
          title: 'That time is no longer available',
          message: failure.code == BookingFailureCode.slotUnavailable
              ? 'Someone else booked it moments ago, or the provider just changed their availability. '
                    "Everything else you've chosen is saved."
              : failure.message,
          action: 'Choose another time',
        );
        draftController.clearSlot();
        ref.invalidate(availableSlotsProvider);
        if (go && context.mounted) popBookingFlowTo(context, AppRoute.selectDateTime);
      case BookingFailureCode.priceChanged || BookingFailureCode.invalidServices:
        final go = await _explain(
          context,
          icon: Icons.sell_outlined,
          title: failure.code == BookingFailureCode.priceChanged ? 'Prices have changed' : 'Services have changed',
          message: failure.message,
          action: 'Review services',
        );
        ref.invalidate(providerServicesProvider(providerId));
        if (go && context.mounted) popBookingFlowTo(context, AppRoute.selectServices);
      case BookingFailureCode.outsideServiceArea ||
          BookingFailureCode.mobileUnavailable ||
          BookingFailureCode.studioUnavailable ||
          BookingFailureCode.addressInvalid ||
          BookingFailureCode.serviceAreaUnavailable:
        final go = await _explain(
          context,
          icon: Icons.wrong_location_outlined,
          title: 'Check the location',
          message: failure.message,
          action: 'Change location',
        );
        if (go && context.mounted) popBookingFlowTo(context, AppRoute.bookingLocation);
      case BookingFailureCode.phoneInvalid || BookingFailureCode.notesTooLong:
        if (context.mounted) {
          context.showAppSnackBar(failure.message, isError: true);
          popBookingFlowTo(context, AppRoute.bookingReview);
        }
      case BookingFailureCode.providerNotAccepting || BookingFailureCode.providerNotFound:
        final go = await _explain(
          context,
          icon: Icons.storefront_outlined,
          title: 'Booking unavailable',
          message: failure.message,
          action: 'Back to profile',
        );
        if (go && context.mounted) popBookingFlowTo(context, AppRoute.publicProviderProfile);
      case BookingFailureCode.clientOverlap || BookingFailureCode.tooManyBookings:
        final go = await _explain(
          context,
          icon: Icons.event_repeat_rounded,
          title: 'You already have a booking',
          message: failure.message,
          action: 'View my bookings',
        );
        if (go && context.mounted) context.goNamed(AppRoute.bookings.name);
      case BookingFailureCode.paymentMethodUnavailable || BookingFailureCode.cardTooFarAhead:
        await _explain(
          context,
          icon: Icons.credit_card_off_outlined,
          title: 'Choose another way to pay',
          message: failure.message,
          action: 'OK',
        );
        // The provider's settings may have just changed: refresh them.
        ref.invalidate(bookingSettingsProvider(providerId));
      default:
        if (context.mounted) context.showAppSnackBar(failure.message, isError: true);
    }
    ref.read(checkoutControllerProvider(providerId).notifier).reset();
  }

  /// Bottom sheet explaining what happened. Returns whether the client took
  /// the suggested action.
  Future<bool> _explain(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String action,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) {
        final scheme = sheetContext.colorScheme;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(icon, size: 30, color: scheme.secondary),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.5, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.65)),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.onSurface,
                      foregroundColor: scheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    child: Text(action),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final selection = ref.watch(serviceSelectionProvider(providerId));
    final draft = ref.watch(bookingDraftProvider(providerId));
    final settings = ref.watch(bookingSettingsProvider(providerId)).value;
    final provider = ref.watch(publicProviderProfileProvider(providerId)).value;
    final config = ref.watch(remoteAppConfigProvider).value ?? const RemoteAppConfig();
    final checkout = ref.watch(checkoutControllerProvider(providerId));
    final providerName = provider == null ? 'the provider' : providerDisplayName(provider);
    final total = Formatters.audCents(selection.totalCents);

    final choices = PaymentChoices.of(
      settings,
      startsAt: draft.slot?.startsAt,
      cardMaxAdvanceDays: config.cardMaxAdvanceDays,
      now: DateTime.now(),
    );
    // A provider who only takes one way of paying gets it pre-selected.
    final fallback = settings == null ? null : choices.fallbackFor(draft.paymentMethod);
    if (fallback != null && !checkout.busy) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) ref.read(bookingDraftProvider(providerId).notifier).selectPaymentMethod(fallback);
      });
    }
    final method = draft.paymentMethod;
    final payNow = !method.isCash;
    // Until settings load, assume a request: the server decides either way.
    final requiresApproval = settings == null || BookingTerms.of(settings, method).requiresApproval;
    final ready = selection.isNotEmpty && draft.hasSlot && draft.hasLocation && choices.allows(method);
    final wallet = walletFor(defaultTargetPlatform);

    final actionLabel = switch ((payNow, requiresApproval)) {
      (false, _) => 'Send request',
      (true, true) => 'Hold $total & send request',
      (true, false) => 'Pay $total',
    };

    void select(PaymentMethod method) =>
        ref.read(bookingDraftProvider(providerId).notifier).selectPaymentMethod(method);

    return PopScope(
      // Don't let a half-sent booking or an open payment be abandoned mid-way.
      canPop: !checkout.busy,
      child: BookingFlowScaffold(
        step: BookingStep.payment,
        title: 'Payment',
        subtitle: provider == null ? null : providerName,
        footer: BookingFooter(
          actionLabel: actionLabel,
          icon: Icons.lock_outline_rounded,
          busy: checkout.busy,
          onAction: ready ? () => _confirm(context, ref) : null,
          summary: BookingFooterSummary(
            // Short: the hold button beside it is wide.
            caption: !payNow ? 'Pay on the day' : (requiresApproval ? 'Card hold' : 'Pay now'),
            value: total,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'How would you like to pay?',
              style: TextStyle(
                fontSize: 22,
                height: 1.25,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 18),
            const BookingSectionLabel('Pay now in the app'),
            PaymentOptionTile(
              icon: Icons.credit_card_rounded,
              title: 'Card or ${wallet.label}',
              subtitle: choices.cardTooFarAhead
                  ? 'Available for appointments up to ${config.cardMaxAdvanceDays} days ahead'
                  : !choices.card
                  ? "$providerName doesn't take payment in the app yet"
                  : requiresApproval
                  ? 'Held on your card, charged only if $providerName accepts'
                  : 'Visa, Mastercard and Amex, paid securely now',
              selected: payNow,
              available: choices.card,
              unavailableLabel: 'Unavailable',
              onTap: () {
                if (choices.card) select(PaymentMethod.card);
              },
            ),
            const SizedBox(height: 22),
            const BookingSectionLabel('Pay at your appointment'),
            PaymentOptionTile(
              icon: Icons.payments_outlined,
              title: 'Pay in cash',
              subtitle: choices.cash
                  ? 'Pay $providerName in person when you arrive'
                  : '$providerName only takes payment in the app',
              selected: !payNow,
              available: choices.cash,
              unavailableLabel: 'Unavailable',
              onTap: () {
                if (choices.cash) select(PaymentMethod.cash);
              },
            ),
            const SizedBox(height: 10),
            PaymentOptionTile(
              icon: Icons.splitscreen_rounded,
              title: PaymentMethod.afterpay.label,
              subtitle: 'Pay in 4 interest-free instalments',
              selected: false,
              available: false,
              onTap: () => context.showComingSoon('Afterpay'),
            ),
            if (checkout.paymentMessage != null) ...[
              const SizedBox(height: 18),
              BookingNotice(
                icon: Icons.error_outline_rounded,
                color: AppTheme.destructive,
                title: "Your payment didn't go through",
                body: '${checkout.paymentMessage} You haven\'t been charged.',
              ),
            ],
            const SizedBox(height: 22),
            _PaymentExplainer(
              payNow: payNow,
              requiresApproval: requiresApproval,
              providerName: providerName,
              total: total,
              holdMinutes: config.checkoutHoldMinutes,
            ),
            const SizedBox(height: 16),
            Text(
              [
                requiresApproval
                    ? "By sending this request you agree to $providerName's cancellation policy. "
                          'Your booking is confirmed once they accept it.'
                    : "By confirming you agree to $providerName's cancellation policy.",
                if (payNow)
                  'Payments are processed by Stripe. If your debit card shows two networks (such as eftpos and Visa), '
                      'your payment may be processed on either.',
              ].join(' '),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

/// What happens to the client's money with the chosen way to pay.
class _PaymentExplainer extends StatelessWidget {
  const _PaymentExplainer({
    required this.payNow,
    required this.requiresApproval,
    required this.providerName,
    required this.total,
    required this.holdMinutes,
  });

  final bool payNow;
  final bool requiresApproval;
  final String providerName;
  final String total;
  final int holdMinutes;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final (title, body) = switch ((payNow, requiresApproval)) {
      (false, _) => (
        'Nothing is charged now',
        'Your payment shows as pending until you pay $providerName $total in cash on the day. '
            'Cash bookings have no booking or cancellation fees.',
      ),
      (true, true) => (
        'Nothing is charged until they accept',
        '$total is held on your card while $providerName looks at your request. If they decline or '
            "don't reply in time, the hold is released.",
      ),
      (true, false) => (
        'Secure payment',
        "You'll pay $total now and the time is yours straight away. We hold it for you for $holdMinutes "
            'minutes while you pay.',
      ),
    };
    return BookingSectionCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(
              payNow ? Icons.lock_outline_rounded : Icons.verified_user_outlined,
              color: AppTheme.success,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(fontSize: 13.5, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
