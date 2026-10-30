import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/widgets/snackbar_utils.dart';
import '../../../../shared/bookings/models/booking_failure.dart';
import '../../../provider_profiles/views/widgets/settings_widgets.dart';
import '../../../schedule/controllers/provider_schedule_controller.dart';

/// How clients can pay this provider: cash, in the app, or both.
///
/// Paying in the app is only offered once card payments are set up. Until
/// then (or while Stripe has paused them) cash stays on whatever the switch
/// says, so clients can always book; the server applies the same rule.
class PaymentOptionsSection extends ConsumerStatefulWidget {
  const PaymentOptionsSection({super.key});

  @override
  ConsumerState<PaymentOptionsSection> createState() => _PaymentOptionsSectionState();
}

class _PaymentOptionsSectionState extends ConsumerState<PaymentOptionsSection> {
  String? _saving;

  Future<void> _save(String column, bool value) async {
    setState(() => _saving = column);
    try {
      await ref.read(providerScheduleActionsProvider).updateSettings({column: value});
    } on BookingFailure catch (failure) {
      if (mounted) context.showAppSnackBar(failure.message, isError: true);
    } catch (_) {
      if (mounted) context.showAppSnackBar("Couldn't save that. Please try again.", isError: true);
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  Widget _trailing(String column, bool value, ValueChanged<bool>? onChanged) => _saving == column
      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
      : Switch.adaptive(value: value, onChanged: _saving == null ? onChanged : null);

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(ownBookingSettingsProvider).value;
    if (settings == null) return const SizedBox.shrink();

    final cardReady = settings.cardReady;
    // Turning one off is only allowed while the other is really available.
    final canTurnOffCash = settings.takesCard;
    final canTurnOffCard = settings.acceptsCash;

    return SettingsSection(
      title: 'How clients pay',
      footer: cardReady
          ? 'Card bookings follow your approval and late-cancellation settings. Cash bookings are always requests with no fees.'
          : 'Paying in the app turns on once your payouts are set up. Until then clients pay cash.',
      children: [
        SettingsTile(
          icon: Icons.credit_card_rounded,
          title: 'Pay in the app',
          subtitle: cardReady ? 'Card, Apple Pay and Google Pay' : 'Set up payouts to turn this on',
          trailing: _trailing(
            'accepts_card',
            settings.acceptsCard && cardReady,
            !cardReady || (settings.acceptsCard && !canTurnOffCard)
                ? null
                : (v) => _save('accepts_card', v),
          ),
        ),
        SettingsTile(
          icon: Icons.payments_outlined,
          title: 'Cash at the appointment',
          subtitle: canTurnOffCash || !settings.acceptsCash
              ? 'Cash bookings are requests you accept'
              : 'Always on until clients can pay in the app',
          trailing: _trailing(
            'accepts_cash',
            settings.takesCash,
            settings.acceptsCash && !canTurnOffCash ? null : (v) => _save('accepts_cash', v),
          ),
        ),
      ],
    );
  }
}
