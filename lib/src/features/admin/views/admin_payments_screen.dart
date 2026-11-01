import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/adaptive/adaptive_list_detail.dart';
import '../controllers/admin_actions.dart';
import '../controllers/admin_controllers.dart';
import '../models/admin_payments.dart';
import '../models/admin_repository.dart';
import 'admin_payment_detail_screen.dart';
import 'widgets/admin_widgets.dart';

/// Card payments: what needs a person (failed jobs, disputes, held shares),
/// then every booking paid in the app, searchable. On wide screens the
/// selected booking's money shows beside the list.
class AdminPaymentsScreen extends ConsumerStatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  ConsumerState<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends ConsumerState<AdminPaymentsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  AdminPaymentsQuery _query = const AdminPaymentsQuery();
  String? _selectedId;

  static const _filters = [
    (null, 'All'),
    ('held', 'Held'),
    ('failed', 'Failed'),
    ('disputed', 'Disputed'),
    ('refunded', 'Refunded'),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(AppConfig.adminSearchDebounce, () {
      if (mounted && text.trim() != _query.text) {
        setState(() => _query = AdminPaymentsQuery(filter: _query.filter, text: text.trim()));
      }
    });
  }

  void _open(String bookingId) {
    if (isWideLayout(context)) {
      setState(() => _selectedId = bookingId);
    } else {
      context.goNamed(AppRoute.adminPayment.name, pathParameters: {'bookingId': bookingId});
    }
  }

  Future<void> _retry(AdminJob job) async {
    final reason = await askAdminReason(context, title: 'Retry ${job.label.toLowerCase()}', summary: job.lastError);
    if (reason == null || !mounted) return;
    await runAdminAction(
      context,
      ref,
      sensitive: true,
      action: () => ref.read(adminRepositoryProvider).retryJob(job.id, reason: reason),
      successMessage: 'Queued again',
    );
    ref.invalidate(adminPaymentsOverviewProvider);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final overview = ref.watch(adminPaymentsOverviewProvider);
    final results = ref.watch(adminPaymentsProvider(_query));

    Future<void> refresh() async {
      ref.invalidate(adminPaymentsOverviewProvider);
      ref.invalidate(adminPaymentsProvider(_query));
    }

    final list = RefreshIndicator(
      onRefresh: refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
            ref.read(adminPaymentsProvider(_query).notifier).loadMore();
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: switch (overview) {
                AsyncData(:final value) => _Overview(overview: value, onOpen: _open, onRetry: _retry),
                AsyncError(:final error) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: AdminErrorView(error: error, onRetry: () => ref.invalidate(adminPaymentsOverviewProvider)),
                ),
                _ => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
              },
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _search,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Reference, client, provider or PaymentIntent id',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: scheme.onSurface.withValues(alpha: 0.04),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final (filter, label) in _filters)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _query.filter == filter,
                          onSelected: (_) =>
                              setState(() => _query = AdminPaymentsQuery(filter: filter, text: _query.text)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            ...switch (results) {
              AsyncData(:final value) when value.items.isEmpty => [
                SliverPadding(
                  padding: const EdgeInsets.all(32),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: Text(
                        'No card payments here yet.',
                        style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ),
                  ),
                ),
              ],
              AsyncData(:final value) => [
                SliverList.builder(
                  itemCount: value.items.length + (value.hasMore || value.loadMoreError != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == value.items.length) {
                      return value.loadMoreError != null
                          ? TextButton(
                              onPressed: () => ref.read(adminPaymentsProvider(_query).notifier).loadMore(),
                              child: const Text("Couldn't load more. Try again"),
                            )
                          : const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                    }
                    final payment = value.items[index];
                    return _PaymentTile(
                      payment: payment,
                      selected: payment.bookingId == _selectedId,
                      onTap: () => _open(payment.bookingId),
                    );
                  },
                ),
              ],
              AsyncError(:final error) => [
                SliverToBoxAdapter(
                  child: AdminErrorView(error: error, onRetry: () => ref.invalidate(adminPaymentsProvider(_query))),
                ),
              ],
              _ => [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
            },
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: AdaptiveListDetail(
        list: list,
        detail: _selectedId == null
            ? null
            : AdminPaymentDetailView(key: ValueKey(_selectedId), bookingId: _selectedId!),
        placeholder: Center(
          child: Text(
            'Select a payment to see its details.',
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.overview, required this.onOpen, required this.onRetry});

  final AdminPaymentsOverview overview;
  final void Function(String bookingId) onOpen;
  final void Function(AdminJob job) onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Last 7 days: ${Formatters.audCents(overview.paid7dCents)} paid in the app · '
            '${Formatters.audCents(overview.fees7dCents)} Myglo fees',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onSurface),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AdminChip(
                label: '${overview.openDisputes} open disputes',
                color: overview.openDisputes > 0 ? AppTheme.destructive : null,
              ),
              AdminChip(
                label: '${overview.heldSettlements} held shares',
                color: overview.heldSettlements > 0 ? AppTheme.warning : null,
              ),
              AdminChip(
                label: '${overview.failedSettlements} failed transfers',
                color: overview.failedSettlements > 0 ? AppTheme.destructive : null,
              ),
              AdminChip(label: '${overview.pendingRefunds} refunds in progress'),
            ],
          ),
          if (overview.disputes.isNotEmpty)
            AdminSection(
              title: 'Open disputes',
              children: [
                for (final dispute in overview.disputes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.gavel_rounded, color: AppTheme.destructive),
                    title: Text('${dispute.reference ?? dispute.id} · ${Formatters.audCents(dispute.amountCents)}'),
                    subtitle: Text(
                      [
                        dispute.reason ?? 'No reason',
                        dispute.status.replaceAll('_', ' '),
                        if (dispute.evidenceDueBy != null) 'respond by ${adminDate(dispute.evidenceDueBy!)}',
                      ].join(' · '),
                    ),
                    onTap: dispute.bookingId == null ? null : () => onOpen(dispute.bookingId!),
                  ),
              ],
            ),
          if (overview.failedJobs.isNotEmpty)
            AdminSection(
              title: 'Failed background jobs',
              children: [
                for (final job in overview.failedJobs)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.error_outline_rounded, color: AppTheme.destructive),
                    title: Text(job.label),
                    subtitle: Text(job.lastError ?? 'No error recorded', maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: job.bookingId == null ? null : () => onOpen(job.bookingId!),
                    trailing: TextButton(onPressed: () => onRetry(job), child: const Text('Retry')),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment, required this.onTap, this.selected = false});

  final AdminPaymentSummary payment;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final flags = [
      if (payment.disputed) ('Disputed', AppTheme.destructive),
      if (payment.settlementStatus == 'held') ('Held', AppTheme.warning),
      if (payment.settlementStatus == 'failed' || payment.paymentStatus == 'failed') ('Failed', AppTheme.destructive),
      if (payment.amountRefundedCents > 0) ('Refunded ${Formatters.audCents(payment.amountRefundedCents)}', null),
    ];
    return ListTile(
      selected: selected,
      onTap: onTap,
      title: Text(
        '${payment.reference} · ${payment.clientName} → ${payment.providerName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${adminDateTime(payment.startsAt)} · ${payment.status.replaceAll('_', ' ')} · ${payment.paymentStatus.replaceAll('_', ' ')}',
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6)),
          ),
          if (flags.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [for (final (label, color) in flags) AdminChip(label: label, color: color)],
            ),
          ],
        ],
      ),
      trailing: Text(Formatters.audCents(payment.totalCents), style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}
