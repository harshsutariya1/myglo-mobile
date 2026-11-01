import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../controllers/payments_controllers.dart';
import '../models/provider_financials.dart';

/// What a provider earned in a month, in the app and in cash, Myglo's fees,
/// what's on its way, and their payouts to the bank.
class FinancialsScreen extends ConsumerStatefulWidget {
  const FinancialsScreen({super.key, this.now});

  /// For tests.
  final DateTime? now;

  @override
  ConsumerState<FinancialsScreen> createState() => _FinancialsScreenState();
}

class _FinancialsScreenState extends ConsumerState<FinancialsScreen> {
  late final DateTime _thisMonth = () {
    final now = widget.now ?? DateTime.now();
    return DateTime(now.year, now.month);
  }();
  late DateTime _month = _thisMonth;

  void _shift(int months) => setState(() => _month = DateTime(_month.year, _month.month + months));

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final financials = ref.watch(providerFinancialsProvider(_month));
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(providerFinancialsProvider(_month)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    Formatters.monthYear(_month),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: scheme.onSurface),
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: _month.isBefore(_thisMonth) ? () => _shift(1) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            switch (financials) {
              AsyncData(:final value) => _Body(financials: value),
              AsyncError() => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text("We couldn't load your earnings.", textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(providerFinancialsProvider(_month)),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              _ => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
            },
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.financials});

  final ProviderFinancials financials;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You earned', style: TextStyle(color: muted)),
              const SizedBox(height: 4),
              Text(
                Formatters.audCents(financials.totalEarnedCents),
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: scheme.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                '${financials.completedBookings} completed ${financials.completedBookings == 1 ? 'booking' : 'bookings'}',
                style: TextStyle(color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Line(label: 'Paid in the app', value: Formatters.audCents(financials.cardEarnedCents)),
        _Line(label: 'Myglo fees', value: '−${Formatters.audCents(financials.mygloFeeCents)}'),
        _Line(label: 'Cash collected', value: Formatters.audCents(financials.cashCollectedCents)),
        if (financials.onItsWayCents > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
            child: Text(
              '${Formatters.audCents(financials.onItsWayCents)} is on its way to your Stripe balance'
              '${financials.heldCents > 0 ? ', including ${Formatters.audCents(financials.heldCents)} on hold' : ''}. '
              'Stripe pays your balance out to your bank every Monday.',
              style: TextStyle(fontSize: 13.5, height: 1.4, color: scheme.onSurface),
            ),
          ),
        ],
        const SizedBox(height: 22),
        Text('Bookings paid in the app', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: scheme.onSurface)),
        const SizedBox(height: 4),
        if (financials.settlements.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('None this month.', style: TextStyle(color: muted)),
          )
        else
          for (final settlement in financials.settlements)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${settlement.clientName} · ${Formatters.dateShort(settlement.startsAt.toLocal())}'),
              subtitle: Text(
                '${settlement.statusLabel}'
                '${settlement.feeCents > 0 ? ' · ${Formatters.audCents(settlement.feeCents)} fee' : ''}',
                style: TextStyle(color: settlement.status == 'held' || settlement.status == 'failed' ? AppTheme.warning : muted),
              ),
              trailing: Text(
                Formatters.audCents(settlement.netCents),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        const SizedBox(height: 18),
        Text('Payouts to your bank', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: scheme.onSurface)),
        const SizedBox(height: 4),
        if (financials.payouts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No payouts yet.', style: TextStyle(color: muted)),
          )
        else
          for (final payout in financials.payouts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                payout.status == 'failed' ? Icons.error_outline_rounded : Icons.account_balance_outlined,
                color: payout.status == 'failed' ? AppTheme.destructive : scheme.secondary,
              ),
              title: Text(payout.statusLabel),
              subtitle: Text(
                payout.status == 'failed'
                    ? payout.failureMessage ?? 'Check your bank details in Payments & payouts.'
                    : payout.arrivalDate == null
                        ? 'Arriving soon'
                        : '${payout.status == 'paid' ? 'Arrived' : 'Expected'} ${Formatters.dateShort(payout.arrivalDate!)}',
                style: TextStyle(color: muted),
              ),
              trailing: Text(Formatters.audCents(payout.amountCents), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.75)))),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface)),
        ],
      ),
    );
  }
}
