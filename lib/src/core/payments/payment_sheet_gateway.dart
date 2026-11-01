import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';

/// How the client left the payment sheet.
enum PaymentSheetOutcome {
  /// The payment (or the hold on the card) went through.
  completed,

  /// The client closed the sheet without paying.
  canceled,

  /// The card was declined, or the sheet couldn't be shown.
  failed,
}

class PaymentSheetResult {
  const PaymentSheetResult(this.outcome, {this.message, this.code});

  const PaymentSheetResult.completed() : this(PaymentSheetOutcome.completed);

  const PaymentSheetResult.canceled() : this(PaymentSheetOutcome.canceled);

  final PaymentSheetOutcome outcome;

  /// What went wrong, in words the client can read (from Stripe when it
  /// gave one).
  final String? message;

  /// Stripe's error or decline code, for logs.
  final String? code;
}

/// What to show in the payment sheet. Amounts never come from the app: the
/// PaymentIntent behind [clientSecret] was created by the server.
class PaymentSheetRequest {
  const PaymentSheetRequest({required this.clientSecret, required this.livemode, this.primaryButtonLabel});

  final String clientSecret;

  /// Whether the PaymentIntent is a live one (Google Pay's test environment
  /// is used otherwise).
  final bool livemode;
  final String? primaryButtonLabel;
}

/// Takes a payment through the platform's payment sheet. Screens and
/// controllers depend on this, never on the Stripe SDK, so tests can use a
/// fake and the payment provider stays swappable.
abstract class PaymentSheetGateway {
  /// Whether payments are configured in this build (a publishable key).
  bool get isConfigured;

  Future<PaymentSheetResult> present(PaymentSheetRequest request);
}

final paymentSheetGatewayProvider = Provider<PaymentSheetGateway>((ref) => StripePaymentSheetGateway());

/// [PaymentSheetGateway] backed by Stripe's PaymentSheet (cards, Apple Pay,
/// Google Pay, 3-D Secure).
///
/// Configuration comes from `.env`: `STRIPE_PUBLISHABLE_KEY` (required) and
/// `APPLE_PAY_MERCHANT_ID` (optional; Apple Pay is offered once it's set and
/// the app has the Apple Pay capability).
class StripePaymentSheetGateway implements PaymentSheetGateway {
  StripePaymentSheetGateway({String? publishableKey, String? appleMerchantId})
    : _publishableKey = publishableKey ?? _env('STRIPE_PUBLISHABLE_KEY'),
      _appleMerchantId = appleMerchantId ?? _env('APPLE_PAY_MERCHANT_ID');

  static const _tag = 'PaymentSheet';

  final String? _publishableKey;
  final String? _appleMerchantId;
  Future<void>? _setup;

  static String? _env(String key) {
    final value = dotenv.isInitialized ? dotenv.maybeGet(key)?.trim() : null;
    return value == null || value.isEmpty ? null : value;
  }

  @override
  bool get isConfigured => _publishableKey != null;

  /// Configures the SDK once, on first use (not at launch, so the app starts
  /// no slower for people who never pay in the app).
  Future<void> _ensureSetUp() => _setup ??=
      () async {
        Stripe.publishableKey = _publishableKey!;
        Stripe.merchantIdentifier = _appleMerchantId;
        Stripe.urlScheme = AppConfig.paymentsUrlScheme;
        await Stripe.instance.applySettings();
      }().catchError((Object error, StackTrace stackTrace) {
        // Let the next attempt try again.
        _setup = null;
        Error.throwWithStackTrace(error, stackTrace);
      });

  @override
  Future<PaymentSheetResult> present(PaymentSheetRequest request) async {
    if (!isConfigured) {
      return const PaymentSheetResult(
        PaymentSheetOutcome.failed,
        message: "Payments aren't set up in this version of the app.",
      );
    }
    try {
      await _ensureSetUp();
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: request.clientSecret,
          merchantDisplayName: AppConfig.paymentsMerchantName,
          primaryButtonLabel: request.primaryButtonLabel,
          applePay: _appleMerchantId == null
              ? null
              : const PaymentSheetApplePay(merchantCountryCode: AppConfig.paymentsMerchantCountry),
          googlePay: PaymentSheetGooglePay(
            merchantCountryCode: AppConfig.paymentsMerchantCountry,
            currencyCode: 'AUD',
            testEnv: !request.livemode,
          ),
          returnURL: '${AppConfig.paymentsUrlScheme}://stripe-redirect',
          style: ThemeMode.system,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(primary: AppTheme.primaryPink),
            shapes: PaymentSheetShape(borderRadius: 14),
          ),
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      return const PaymentSheetResult.completed();
    } on StripeException catch (e) {
      final error = e.error;
      if (error.code == FailureCode.Canceled) return const PaymentSheetResult.canceled();
      AppLogger.w(
        'Payment sheet failed: ${error.code.name} ${error.stripeErrorCode ?? ''} ${error.declineCode ?? ''}',
        tag: _tag,
      );
      return PaymentSheetResult(
        PaymentSheetOutcome.failed,
        message: error.localizedMessage ?? error.message,
        code: error.declineCode ?? error.stripeErrorCode,
      );
    }
  }
}
