import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../controllers/admin_actions.dart';
import '../controllers/admin_controllers.dart';
import '../models/admin_payments.dart';
import '../models/admin_repository.dart';
import 'widgets/admin_widgets.dart';

/// One booking's money, as its own page (phones).
class AdminPaymentDetailScreen extends StatelessWidget {
  const AdminPaymentDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: AdminPaymentDetailView(bookingId: bookingId),
    );
  }
}

/// A booking's payment, refunds, the provider's share, disputes, background
/// jobs and timeline, with the admin actions that apply. Every action asks
/// for a reason and a fresh authenticator code; the server checks both.
class AdminPaymentDetailView extends ConsumerWidget {
  const AdminPaymentDetailView({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(adminBookingPaymentProvider(bookingId));
    return switch (detail) {
      AsyncData(:final value) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminBookingPaymentProvider(bookingId)),
        child: _Detail(payment: value),
      ),
      AsyncError(:final error) => AdminErrorView(
        error: error,
        onRetry: () => ref.invalidate(adminBookingPaymentProvider(bookingId)),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.payment});

  final AdminBookingPayment payment;

  String _money(Object? cents) => Formatters.audCents(cents is num ? cents.toInt() : 0);

  String _label(Object? value) => '${value ?? '—'}'.replaceAll('_', ' ');

  DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse('$value');

  Future<void> _afterAction(WidgetRef ref) async {
    ref.invalidate(adminBookingPaymentProvider(payment.bookingId));
    ref.invalidate(adminPaymentsOverviewProvider);
    ref.invalidate(adminPaymentsProvider);
  }

  Future<void> _refund(BuildContext context, WidgetRef ref) async {
    final request = await showDialog<({int cents, bool recover})>(
      context: context,
      builder: (_) => _RefundDialog(
        refundableCents: payment.refundableCents,
        providerPaid: payment.settlementStatus == 'transferred',
      ),
    );
    if (request == null || !context.mounted) return;
    final reason = await askAdminReason(
      context,
      title: 'Refund ${Formatters.audCents(request.cents)}',
      summary: 'Booking ${payment.reference}. The client gets the money back on their card.',
    );
    if (reason == null || !context.mounted) return;
    await runAdminAction(
      context,
      ref,
      sensitive: true,
      action: () => ref
          .read(adminRepositoryProvider)
          .refundBooking(payment.bookingId, amountCents: request.cents, reason: reason, recover: request.recover),
      successMessage: 'Refund queued',
    );
    await _afterAction(ref);
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final reason = await askAdminReason(
      context,
      title: 'Cancel booking ${payment.reference}',
      summary: payment.paymentMethod == 'cash'
          ? 'Both sides are told Myglo cancelled it.'
          : 'Both sides are told Myglo cancelled it, and the client is refunded in full.',
    );
    if (reason == null || !context.mounted) return;
    await runAdminAction(
      context,
      ref,
      sensitive: true,
      action: () => ref.read(adminRepositoryProvider).cancelBooking(payment.bookingId, reason: reason),
      successMessage: 'Booking cancelled',
    );
    await _afterAction(ref);
  }

  Future<void> _hold(BuildContext context, WidgetRef ref, {required bool hold}) async {
    final reason = await askAdminReason(
      context,
      title: hold ? "Hold the provider's share" : "Release the provider's share",
      summary: hold
          ? 'It stays with Myglo until released.'
          : 'It is transferred to the provider if their account can receive it.',
    );
    if (reason == null || !context.mounted) return;
    await runAdminAction(
      context,
      ref,
      sensitive: true,
      action: () => ref.read(adminRepositoryProvider).setSettlementHold(payment.bookingId, hold: hold, reason: reason),
      successMessage: hold ? 'Share held' : 'Share released',
    );
    await _afterAction(ref);
  }

  Future<void> _retry(BuildContext context, WidgetRef ref, AdminJob job) async {
    final reason = await askAdminReason(context, title: 'Retry ${job.label.toLowerCase()}', summary: job.lastError);
    if (reason == null || !context.mounted) return;
    await runAdminAction(
      context,
      ref,
      sensitive: true,
      action: () => ref.read(adminRepositoryProvider).retryJob(job.id, reason: reason),
      successMessage: 'Queued again',
    );
    await _afterAction(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final booking = payment.booking;
    final card = payment.payment;
    final settlement = payment.settlement;
    final startsAt = _date(booking['starts_at']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text(
          '${payment.reference} · ${Formatters.audCents(payment.totalCents)}',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: scheme.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          '${booking['client_name']} → ${booking['provider_name']}${startsAt == null ? '' : ' · ${adminDateTime(startsAt)}'}',
          style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.65)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (payment.canRefund)
              FilledButton.icon(
                onPressed: () => _refund(context, ref),
                icon: const Icon(Icons.currency_exchange_rounded, size: 18),
                label: const Text('Refund'),
              ),
            if (payment.canCancel)
              OutlinedButton.icon(
                onPressed: () => _cancel(context, ref),
                icon: const Icon(Icons.event_busy_rounded, size: 18),
                label: const Text('Cancel booking'),
              ),
            if (payment.canHold)
              OutlinedButton.icon(
                onPressed: () => _hold(context, ref, hold: true),
                icon: const Icon(Icons.pause_circle_outline_rounded, size: 18),
                label: const Text('Hold share'),
              ),
            if (payment.canRelease)
              OutlinedButton.icon(
                onPressed: () => _hold(context, ref, hold: false),
                icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                label: const Text('Release share'),
              ),
          ],
        ),
        AdminSection(
          title: 'Booking',
          children: [
            AdminInfoRow(label: 'Status', value: _label(booking['status'])),
            AdminInfoRow(
              label: 'Payment',
              value: '${_label(booking['payment_method'])} · ${_label(booking['payment_status'])}',
            ),
            AdminInfoRow(
              label: 'Myglo fee',
              value: '${_money(booking['platform_fee_cents'])} (${booking['platform_fee_percent']}%)',
            ),
            if ((booking['cancellation_fee_cents'] as num? ?? 0) > 0)
              AdminInfoRow(label: 'Late fee', value: _money(booking['cancellation_fee_cents'])),
            AdminInfoRow(label: 'Refundable', value: _money(booking['refundable_cents'])),
          ],
        ),
        if (card != null && payment.paymentMethod != 'cash')
          AdminSection(
            title: 'Card payment',
            children: [
              AdminInfoRow(label: 'Status', value: _label(card['status'])),
              AdminInfoRow(
                label: 'Card',
                value: [
                  card['wallet'],
                  card['card_brand'],
                  if (card['card_last4'] != null) '•• ${card['card_last4']}',
                ].whereType<Object>().map(_label).join(' · '),
              ),
              AdminInfoRow(label: 'Refunded', value: _money(card['amount_refunded_cents'])),
              if (card['failure_code'] != null)
                AdminInfoRow(label: 'Last decline', value: _label(card['failure_code'])),
              _CopyRow(label: 'PaymentIntent', value: card['stripe_payment_intent_id'] as String?),
              _CopyRow(label: 'Charge', value: card['stripe_charge_id'] as String?),
            ],
          ),
        if (payment.refunds.isNotEmpty)
          AdminSection(
            title: 'Refunds',
            children: [
              for (final refund in payment.refunds)
                AdminInfoRow(
                  label: '${_label(refund['reason'])} (${_label(refund['initiated_by'])})',
                  value: '${_money(refund['amount_cents'])} · ${_label(refund['status'])}',
                  valueColor: refund['status'] == 'failed' ? AppTheme.destructive : null,
                ),
            ],
          ),
        if (settlement != null)
          AdminSection(
            title: "Provider's share",
            children: [
              AdminInfoRow(
                label: 'Status',
                value: [
                  _label(settlement['status']),
                  if (settlement['hold_reason'] != null) _label(settlement['hold_reason']),
                ].join(' · '),
                valueColor: switch (settlement['status']) {
                  'held' => AppTheme.warning,
                  'failed' || 'reversed' => AppTheme.destructive,
                  'transferred' => AppTheme.success,
                  _ => null,
                },
              ),
              AdminInfoRow(label: 'Kept by provider', value: _money(settlement['kept_cents'])),
              AdminInfoRow(label: 'Myglo fee', value: _money(settlement['platform_fee_cents'])),
              AdminInfoRow(label: 'Transfer', value: _money(settlement['transfer_cents'])),
              if ((settlement['reversed_cents'] as num? ?? 0) > 0)
                AdminInfoRow(label: 'Taken back', value: _money(settlement['reversed_cents'])),
              if (settlement['hold_note'] != null)
                AdminInfoRow(label: 'Hold note', value: '${settlement['hold_note']}'),
              if (settlement['failure_reason'] != null)
                AdminInfoRow(
                  label: 'Failure',
                  value: '${settlement['failure_reason']}',
                  valueColor: AppTheme.destructive,
                ),
              _CopyRow(label: 'Transfer', value: settlement['stripe_transfer_id'] as String?),
            ],
          ),
        if (payment.disputes.isNotEmpty)
          AdminSection(
            title: 'Disputes',
            children: [
              for (final dispute in payment.disputes)
                AdminInfoRow(
                  label: dispute.reason == null ? dispute.id : _label(dispute.reason),
                  value:
                      '${Formatters.audCents(dispute.amountCents)} · ${_label(dispute.status)}'
                      '${dispute.evidenceDueBy == null ? '' : '\nRespond by ${adminDate(dispute.evidenceDueBy!)}'}',
                  valueColor: AppTheme.destructive,
                ),
            ],
          ),
        if (payment.jobs.isNotEmpty)
          AdminSection(
            title: 'Background jobs',
            children: [
              for (final job in payment.jobs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('${job.label} · ${job.status}'),
                  subtitle: job.lastError == null
                      ? null
                      : Text(job.lastError!, maxLines: 3, overflow: TextOverflow.ellipsis),
                  trailing: job.status == 'failed'
                      ? TextButton(onPressed: () => _retry(context, ref, job), child: const Text('Retry'))
                      : Text('${job.attempts}×', style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5))),
                ),
            ],
          ),
        AdminSection(
          title: 'Timeline',
          children: [
            for (final event in payment.events.reversed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('${_label(event['event'])} · ${_label(event['actor_role'])}'),
                subtitle: Text(
                  [
                    if (_date(event['created_at']) != null) adminDateTime(_date(event['created_at'])!),
                    if (event['to_status'] != null) '→ ${_label(event['to_status'])}',
                  ].join(' '),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final id = value;
    if (id == null) return const SizedBox.shrink();
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: id));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label id copied')));
      },
      child: AdminInfoRow(label: label, value: id),
    );
  }
}

class _RefundDialog extends StatefulWidget {
  const _RefundDialog({required this.refundableCents, required this.providerPaid});

  final int refundableCents;

  /// The provider was already paid, so their part can be taken back.
  final bool providerPaid;

  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  late final _amount = TextEditingController(text: (widget.refundableCents / 100).toStringAsFixed(2));
  bool _recover = true;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int? get _cents {
    final value = double.tryParse(_amount.text.replaceAll(r'$', '').trim());
    if (value == null) return null;
    final cents = (value * 100).round();
    return cents > 0 && cents <= widget.refundableCents ? cents : null;
  }

  @override
  Widget build(BuildContext context) {
    final cents = _cents;
    return AlertDialog(
      title: const Text('Refund the client'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Up to ${Formatters.audCents(widget.refundableCents)} can be refunded.'),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: InputDecoration(
              labelText: 'Amount (AUD)',
              prefixText: r'$',
              errorText: _amount.text.isNotEmpty && cents == null
                  ? 'Enter up to ${Formatters.audCents(widget.refundableCents)}'
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (widget.providerPaid)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _recover,
              onChanged: (value) => setState(() => _recover = value),
              title: const Text('Take it back from the provider'),
              subtitle: const Text('Their part of the refund is reversed from their Stripe balance.'),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: cents == null ? null : () => Navigator.of(context).pop((cents: cents, recover: _recover)),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
