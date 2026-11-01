import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/payments_repository.dart';
import '../models/payments_setup.dart';
import '../models/provider_financials.dart';

/// The signed-in provider's payments set-up. Refresh it with
/// [PaymentsSetupController.refreshFromStripe] after onboarding.
final paymentsSetupProvider = AsyncNotifierProvider.autoDispose<PaymentsSetupController, PaymentsSetup>(
  PaymentsSetupController.new,
);

class PaymentsSetupController extends AsyncNotifier<PaymentsSetup> {
  @override
  Future<PaymentsSetup> build() => ref.read(paymentsRepositoryProvider).getSetup();

  /// Fetches the account's state from Stripe (not just the stored copy), for
  /// when the provider comes back from Stripe's onboarding.
  Future<void> refreshFromStripe() async {
    try {
      final setup = await ref.read(paymentsRepositoryProvider).refresh();
      if (ref.mounted) state = AsyncData(setup);
    } catch (_) {
      // Keep showing what we had; the webhook will catch the change up.
    }
  }
}

/// The provider's money for the calendar month starting [month] (a local
/// first-of-month date).
final providerFinancialsProvider = FutureProvider.autoDispose.family<ProviderFinancials, DateTime>((ref, month) {
  final end = DateTime(month.year, month.month + 1, 0);
  return ref.watch(paymentsRepositoryProvider).getFinancials(from: month, to: end);
});
