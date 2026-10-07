import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../../providers/provider_profiles/controllers/provider_services_controller.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../shared/bookings/controllers/booking_controllers.dart';
import '../../../shared/bookings/models/booking_enums.dart';
import '../../../shared/bookings/models/booking_failure.dart';
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

/// Step 5: choose how to pay and place the booking.
///
/// Only cash is live; card, wallet and buy-now-pay-later rails are listed as
/// coming soon. Placing the booking re-checks everything server-side in one
/// transaction (the time, prices, travel area); if something changed, the
/// client is taken straight to the step that needs attention with their
/// other choices intact.
class BookingPaymentScreen extends ConsumerWidget {
  const BookingPaymentScreen({super.key, required this.providerId});

  final String providerId;

  /// Wallet shown for this platform.
  static PaymentMethod walletFor(TargetPlatform platform) =>
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS ? PaymentMethod.applePay : PaymentMethod.googlePay;

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
    final error = ref.read(checkoutControllerProvider(providerId)).error;
    if (error != null) await _handleFailure(context, ref, BookingFailure.from(error));
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
    final submitting = ref.watch(checkoutControllerProvider(providerId)).isLoading;
    final providerName = provider == null ? 'the provider' : providerDisplayName(provider);
    final requiresApproval = settings?.requiresApproval ?? false;
    final ready = selection.isNotEmpty && draft.hasSlot && draft.hasLocation;
    final wallet = walletFor(defaultTargetPlatform);

    void comingSoon(String what) => context.showComingSoon(what);

    return PopScope(
      // Don't let a half-sent booking be abandoned mid-request.
      canPop: !submitting,
      child: BookingFlowScaffold(
        step: BookingStep.payment,
        title: 'Payment',
        subtitle: provider == null ? null : providerName,
        footer: BookingFooter(
          actionLabel: requiresApproval ? 'Send request' : 'Confirm booking',
          icon: Icons.lock_outline_rounded,
          busy: submitting,
          onAction: ready && draft.paymentMethod == PaymentMethod.cash ? () => _confirm(context, ref) : null,
          summary: BookingFooterSummary(caption: 'Pay on the day', value: Formatters.audCents(selection.totalCents)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'How would you like to pay?',
              style: TextStyle(fontSize: 22, height: 1.25, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: scheme.onSurface),
            ),
            const SizedBox(height: 18),
            const BookingSectionLabel('Pay at your appointment'),
            PaymentOptionTile(
              icon: Icons.payments_outlined,
              title: 'Pay in cash',
              subtitle: 'Pay $providerName in person when you arrive',
              selected: draft.paymentMethod == PaymentMethod.cash,
              onTap: () => ref.read(bookingDraftProvider(providerId).notifier).selectPaymentMethod(PaymentMethod.cash),
            ),
            const SizedBox(height: 22),
            const BookingSectionLabel('Pay in the app'),
            PaymentOptionTile(
              icon: Icons.credit_card_rounded,
              title: PaymentMethod.card.label,
              subtitle: 'Visa, Mastercard and Amex',
              selected: false,
              available: false,
              onTap: () => comingSoon('Card payments'),
            ),
            const SizedBox(height: 10),
            PaymentOptionTile(
              icon: wallet == PaymentMethod.applePay ? Icons.apple_rounded : Icons.account_balance_wallet_outlined,
              title: wallet.label,
              subtitle: 'Fast, secure checkout with your phone',
              selected: false,
              available: false,
              onTap: () => comingSoon(wallet.label),
            ),
            const SizedBox(height: 10),
            PaymentOptionTile(
              icon: Icons.splitscreen_rounded,
              title: PaymentMethod.afterpay.label,
              subtitle: 'Pay in 4 interest-free instalments',
              selected: false,
              available: false,
              onTap: () => comingSoon('Afterpay'),
            ),
            const SizedBox(height: 22),
            BookingSectionCard(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.verified_user_outlined, color: AppTheme.success, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nothing is charged now',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scheme.onSurface),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Your payment shows as pending until you pay $providerName '
                          '${Formatters.audCents(selection.totalCents)} in cash on the day.',
                          style: TextStyle(fontSize: 13.5, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              requiresApproval
                  ? "By sending this request you agree to $providerName's cancellation policy. "
                      'Your booking is confirmed once they accept it.'
                  : "By confirming you agree to $providerName's cancellation policy.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }
}
