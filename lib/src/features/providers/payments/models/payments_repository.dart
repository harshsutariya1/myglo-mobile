import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/network_error.dart';
import '../../../shared/authentication/models/auth_repository.dart';
import 'payments_setup.dart';

final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => PaymentsRepository(ref.watch(supabaseClientProvider)),
);

/// Why a payments action didn't work.
enum PaymentsFailureCode { unavailable, notOnboarded, notAllowed, offline, unknown }

class PaymentsFailure implements Exception {
  const PaymentsFailure(this.code);

  final PaymentsFailureCode code;

  static PaymentsFailure from(Object error) {
    if (error is PaymentsFailure) return error;
    if (error is FunctionException) {
      final code = error.details is Map ? (error.details as Map)['error'] : null;
      return PaymentsFailure(switch (code) {
        'not_onboarded' => PaymentsFailureCode.notOnboarded,
        'providers_only' || 'not_authenticated' => PaymentsFailureCode.notAllowed,
        'payments_unavailable' => PaymentsFailureCode.unavailable,
        _ => error.status >= 500 ? PaymentsFailureCode.unavailable : PaymentsFailureCode.unknown,
      });
    }
    if (isConnectivityError(error)) return const PaymentsFailure(PaymentsFailureCode.offline);
    return const PaymentsFailure(PaymentsFailureCode.unknown);
  }

  String get message => switch (code) {
        PaymentsFailureCode.unavailable => "Card payments can't be set up right now. Please try again shortly.",
        PaymentsFailureCode.notOnboarded => 'Set up payouts first.',
        PaymentsFailureCode.notAllowed => 'Only provider accounts can take card payments.',
        PaymentsFailureCode.offline => "You're offline. Check your connection and try again.",
        PaymentsFailureCode.unknown => 'Something went wrong. Please try again.',
      };

  @override
  String toString() => 'PaymentsFailure($code)';
}

/// A provider's card payments and payouts. Stripe calls happen in the
/// `connect` Edge Function; the database decides who may make them.
class PaymentsRepository {
  PaymentsRepository(this._client);

  final SupabaseClient _client;

  static const _tag = 'PaymentsRepository';

  Future<PaymentsSetup> getSetup() async {
    final sw = Stopwatch()..start();
    try {
      final row = await _client.rpc('get_my_payments_setup');
      sw.stop();
      AppLogger.api('rpc.get_my_payments_setup', duration: sw.elapsed);
      return PaymentsSetup.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (e, st) {
      AppLogger.e('Loading payments set-up failed', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  /// A one-time Stripe link to set up (or update) payout details.
  Future<Uri> onboardingLink() async => Uri.parse((await _connect('onboard'))['url'] as String);

  /// Asks Stripe for the account's latest state and returns the set-up.
  Future<PaymentsSetup> refresh() async => PaymentsSetup.fromJson(await _connect('status'));

  /// A one-time link to the provider's Stripe Express Dashboard.
  Future<Uri> dashboardLink() async => Uri.parse((await _connect('dashboard'))['url'] as String);

  Future<Map<String, dynamic>> _connect(String action) async {
    final sw = Stopwatch()..start();
    try {
      final response = await _client.functions.invoke('connect', body: {'action': action});
      sw.stop();
      AppLogger.api('fn.connect', endpoint: action, duration: sw.elapsed);
      return Map<String, dynamic>.from(response.data as Map);
    } catch (e, st) {
      final failure = PaymentsFailure.from(e);
      if (failure.code == PaymentsFailureCode.offline) {
        AppLogger.w('connect $action offline', tag: _tag, error: e);
      } else {
        AppLogger.e('connect $action failed', tag: _tag, error: e, stackTrace: st);
      }
      Error.throwWithStackTrace(failure, st);
    }
  }
}
