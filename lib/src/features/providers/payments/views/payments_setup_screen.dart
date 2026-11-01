import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../controllers/payments_controllers.dart';
import '../models/payments_repository.dart';
import '../models/payments_setup.dart';
import 'widgets/payment_options_section.dart';

/// "Payments & payouts": set up the Stripe account card payments are paid
/// out to, see what Stripe needs, the Myglo fee, and choose cash and/or card.
///
/// Stripe's onboarding opens in an in-app browser; when the provider comes
/// back the screen asks Stripe for the account's new state (the webhook
/// does too, a moment later).
class PaymentsSetupScreen extends ConsumerStatefulWidget {
  const PaymentsSetupScreen({super.key});

  @override
  ConsumerState<PaymentsSetupScreen> createState() => _PaymentsSetupScreenState();
}

class _PaymentsSetupScreenState extends ConsumerState<PaymentsSetupScreen> with WidgetsBindingObserver {
  bool _opening = false;

  /// Set while the provider is away in Stripe's onboarding.
  bool _awaitingReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingReturn) {
      _awaitingReturn = false;
      ref.read(paymentsSetupProvider.notifier).refreshFromStripe();
    }
  }

  Future<void> _openStripe({required bool dashboard}) async {
    setState(() => _opening = true);
    try {
      final repo = ref.read(paymentsRepositoryProvider);
      final url = dashboard ? await repo.dashboardLink() : await repo.onboardingLink();
      // Onboarding stays in an in-app browser tab; Stripe's Express Dashboard
      // must open in the real browser.
      final opened = await launchUrl(url, mode: dashboard ? LaunchMode.externalApplication : LaunchMode.inAppBrowserView);
      if (!opened) throw const PaymentsFailure(PaymentsFailureCode.unknown);
      if (!dashboard) _awaitingReturn = true;
    } catch (e) {
      if (mounted) context.showAppSnackBar(PaymentsFailure.from(e).message, isError: true);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(paymentsSetupProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Payments & payouts')),
      body: switch (setup) {
        AsyncData(:final value) => RefreshIndicator(
            onRefresh: () => ref.read(paymentsSetupProvider.notifier).refreshFromStripe(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _StatusCard(setup: value),
                const SizedBox(height: 16),
                _PrimaryAction(
                  setup: value,
                  busy: _opening,
                  onSetUp: () => _openStripe(dashboard: false),
                  onDashboard: () => _openStripe(dashboard: true),
                ),
                if (value.status.canTakeCards) ...[
                  const SizedBox(height: 12),
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.insights_rounded),
                      title: const Text('Earnings'),
                      subtitle: const Text('What you earned, your share of each booking and your payouts'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.pushNamed(AppRoute.providerEarnings.name),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _FeeCard(setup: value),
                const SizedBox(height: 16),
                const _HowItWorks(),
                const SizedBox(height: 8),
                const PaymentOptionsSection(),
              ],
            ),
          ),
        AsyncError() => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("We couldn't load your payment set-up.", textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: () => ref.invalidate(paymentsSetupProvider), child: const Text('Try again')),
                ],
              ),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.setup});

  final PaymentsSetup setup;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final (icon, color, title, body) = switch (setup.status) {
      PaymentsSetupStatus.notStarted => (
          Icons.credit_card_rounded,
          scheme.secondary,
          'Take card payments',
          'Let clients pay when they book, by card, Apple Pay or Google Pay. Set up payouts with Stripe, '
              "Myglo's payments partner, to get started. It takes about 5 minutes.",
        ),
      PaymentsSetupStatus.onboarding => (
          Icons.pending_actions_rounded,
          AppTheme.warning,
          'Finish setting up payouts',
          'Stripe needs a few more details before you can take card payments.',
        ),
      PaymentsSetupStatus.verifying => (
          Icons.hourglass_top_rounded,
          AppTheme.warning,
          'Stripe is checking your details',
          'This usually takes a few minutes, sometimes a day or two. We will let you know when card payments are on.',
        ),
      PaymentsSetupStatus.active => (
          Icons.check_circle_rounded,
          AppTheme.success,
          'Card payments are on',
          'Clients can pay you in the app. Payouts go to your bank every Monday.',
        ),
      PaymentsSetupStatus.actionNeeded => (
          Icons.info_rounded,
          AppTheme.warning,
          'Stripe needs a few details',
          'Card payments still work, but update your details to keep them on.',
        ),
      PaymentsSetupStatus.restricted => (
          Icons.error_rounded,
          AppTheme.destructive,
          'Card payments are paused',
          'Give Stripe the details below to start taking card payments and receiving payouts again. '
              'Clients can still book and pay cash meanwhile.',
        ),
      PaymentsSetupStatus.rejected || PaymentsSetupStatus.closed || PaymentsSetupStatus.unknown => (
          Icons.block_rounded,
          AppTheme.destructive,
          "Card payments aren't available",
          "Stripe can't support card payments for this account. Clients can still book and pay cash. "
              'Contact Myglo support if you think this is wrong.',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: scheme.onSurface)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(fontSize: 14.5, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.75))),
          if (setup.requirementsDue.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              setup.requirementsDeadline == null
                  ? 'Stripe needs:'
                  : 'Stripe needs, by ${Formatters.dateLong(setup.requirementsDeadline!.toLocal(), withYear: true)}:',
              style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
            ),
            const SizedBox(height: 4),
            for (final item in setup.requirementsDue.take(6))
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('• $item', style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.75))),
              ),
          ],
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.setup, required this.busy, required this.onSetUp, required this.onDashboard});

  final PaymentsSetup setup;
  final bool busy;
  final VoidCallback onSetUp;
  final VoidCallback onDashboard;

  @override
  Widget build(BuildContext context) {
    final spinner = const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5));
    final status = setup.status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (status.needsProvider)
          FilledButton(
            onPressed: busy ? null : onSetUp,
            child: busy ? spinner : Text(status == PaymentsSetupStatus.notStarted ? 'Set up payouts' : 'Continue with Stripe'),
          ),
        if (status.canTakeCards || status == PaymentsSetupStatus.restricted) ...[
          if (status.needsProvider) const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: busy ? null : onDashboard,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Bank details & payout history'),
          ),
        ],
      ],
    );
  }
}

class _FeeCard extends StatelessWidget {
  const _FeeCard({required this.setup});

  final PaymentsSetup setup;

  String get _fee {
    final percent = setup.feePercent;
    return percent == percent.roundToDouble() ? '${percent.round()}%' : '$percent%';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final now = DateTime.now();
    final String line;
    if (setup.feePercent == 0) {
      line = 'No Myglo fee on card bookings right now.';
    } else if (setup.feeFreeUntil != null && now.isBefore(setup.feeFreeUntil!)) {
      line = 'Free until ${Formatters.dateLong(setup.feeFreeUntil!.toLocal(), withYear: true)}, '
          'then $_fee of each card booking.';
    } else if (setup.feeFreeUntil == null && setup.feeFreeDays > 0) {
      line = 'Your first ${setup.feeFreeDays} days of card payments are free, then $_fee of each card booking.';
    } else {
      line = '$_fee of each card booking, taken before your payout. It covers card processing.';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.percent_rounded, color: scheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Myglo fee', style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface)),
                const SizedBox(height: 2),
                Text(line, style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7), height: 1.35)),
                const SizedBox(height: 2),
                Text('Cash bookings never have a fee.',
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.55))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    const steps = [
      (Icons.lock_clock_outlined, 'Clients pay when they book. For requests, the card is held and only charged when you accept.'),
      (Icons.task_alt_rounded, "You're paid once the appointment is done: when you mark it complete, or a day after it ends."),
      (Icons.account_balance_outlined, 'Payouts reach your bank every Monday.'),
      (Icons.event_busy_outlined, 'Late cancellations and no-shows pay your late-cancellation fee; the rest is refunded.'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How card payments work', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: scheme.onSurface)),
        const SizedBox(height: 8),
        for (final (icon, text) in steps)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: scheme.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(text, style: TextStyle(height: 1.4, color: scheme.onSurface.withValues(alpha: 0.75))),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
