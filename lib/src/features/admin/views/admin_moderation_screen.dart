import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../shared/reports/models/report.dart';
import '../controllers/admin_actions.dart';
import '../controllers/admin_controllers.dart';
import '../models/admin_moderation.dart';
import '../models/admin_repository.dart';
import 'widgets/admin_widgets.dart';

/// Reports from clients and providers: the open queue first, then closed
/// ones. Each report opens with what it's about and what can be done:
/// hide the content, look at the account or payment, resolve or dismiss.
class AdminModerationScreen extends ConsumerStatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  ConsumerState<AdminModerationScreen> createState() => _AdminModerationScreenState();
}

class _AdminModerationScreenState extends ConsumerState<AdminModerationScreen> {
  String _status = 'open';

  static const _statuses = [('open', 'Open'), ('resolved', 'Resolved'), ('dismissed', 'Dismissed')];

  Future<void> _open(AdminReport report) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => AdminReportSheet(report: report),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final reports = ref.watch(adminReportsProvider(_status));

    return Scaffold(
      appBar: AppBar(title: const Text('Moderation')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminReportsProvider(_status)),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
              ref.read(adminReportsProvider(_status).notifier).loadMore();
            }
            return false;
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final (status, label) in _statuses)
                        ChoiceChip(
                          label: Text(label),
                          selected: _status == status,
                          onSelected: (_) => setState(() => _status = status),
                        ),
                    ],
                  ),
                ),
              ),
              ...switch (reports) {
                AsyncData(:final value) when value.items.isEmpty => [
                  SliverPadding(
                    padding: const EdgeInsets.all(32),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: Text(
                          _status == 'open' ? 'Nothing to review. Nice.' : 'No reports here yet.',
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
                                onPressed: () => ref.read(adminReportsProvider(_status).notifier).loadMore(),
                                child: const Text("Couldn't load more. Try again"),
                              )
                            : const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              );
                      }
                      final report = value.items[index];
                      return AdminReportTile(report: report, onTap: () => _open(report));
                    },
                  ),
                ],
                AsyncError(:final error) => [
                  SliverToBoxAdapter(
                    child: AdminErrorView(error: error, onRetry: () => ref.invalidate(adminReportsProvider(_status))),
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
      ),
    );
  }
}

IconData _iconFor(ReportTarget target) => switch (target) {
  ReportTarget.post => Icons.photo_outlined,
  ReportTarget.comment => Icons.chat_bubble_outline_rounded,
  ReportTarget.review => Icons.rate_review_outlined,
  ReportTarget.provider => Icons.storefront_outlined,
  ReportTarget.booking => Icons.event_note_outlined,
};

String _capitalised(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// One report in the queue.
class AdminReportTile extends StatelessWidget {
  const AdminReportTile({super.key, required this.report, required this.onTap});

  final AdminReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final subject = report.subject;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: (report.reason.isUrgent ? AppTheme.destructive : scheme.secondary).withValues(alpha: 0.12),
        child: Icon(
          _iconFor(report.target),
          color: report.reason.isUrgent ? AppTheme.destructive : scheme.secondary,
          size: 20,
        ),
      ),
      title: Text(
        '${_capitalised(report.target.noun)} · ${report.reason.adminLabel}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subject.exists ? (subject.text ?? '(no text)') : 'Since deleted',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${Formatters.relativeTime(report.createdAt)} · ${report.reporterName ?? 'Deleted account'}',
                style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.55)),
              ),
              if (report.reason.isUrgent) const AdminChip(label: 'Urgent', color: AppTheme.destructive),
              if (report.reportsOnTarget > 1)
                AdminChip(label: '${report.reportsOnTarget} reports', color: AppTheme.warning),
              if (subject.hidden) const AdminChip(label: 'Hidden'),
            ],
          ),
        ],
      ),
      isThreeLine: true,
    );
  }
}

/// A report with everything an admin can do about it.
class AdminReportSheet extends ConsumerWidget {
  const AdminReportSheet({super.key, required this.report});

  final AdminReport report;

  void _refreshQueue(WidgetRef ref) {
    for (final status in const ['open', 'resolved', 'dismissed']) {
      ref.invalidate(adminReportsProvider(status));
    }
  }

  Future<void> _close(BuildContext context, WidgetRef ref, {required bool dismiss}) async {
    final note = await askAdminReason(
      context,
      title: dismiss ? 'Dismiss report' : 'Resolve report',
      summary: dismiss
          ? 'Nothing needs doing. The reporter sees the report as closed.'
          : 'Say what was done (hidden, refunded, account suspended…).',
    );
    if (note == null || !context.mounted) return;
    final closed = await runAdminAction(
      context,
      ref,
      action: () async {
        await ref.read(adminRepositoryProvider).resolveReport(report.id, dismiss: dismiss, note: note);
        return true;
      },
      successMessage: dismiss ? 'Report dismissed' : 'Report resolved',
    );
    _refreshQueue(ref);
    if (closed == true && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _setHidden(BuildContext context, WidgetRef ref, {required bool hidden}) async {
    final noun = report.target.noun;
    final reason = await askAdminReason(
      context,
      title: hidden ? 'Hide this $noun' : 'Show this $noun again',
      summary: hidden
          ? switch (report.target) {
              ReportTarget.review =>
                'Only its author will see it, and it stops counting towards the rating. Its photos are hidden too.',
              _ => 'Only its author will see it, marked as hidden by Myglo.',
            }
          : 'Everyone will see it again.',
    );
    if (reason == null || !context.mounted) return;
    final done = await runAdminAction(
      context,
      ref,
      sensitive: true,
      action: () async {
        await ref
            .read(adminRepositoryProvider)
            .setContentHidden(report.target, report.targetId, hidden: hidden, reason: reason);
        return true;
      },
      successMessage: hidden ? '${_capitalised(noun)} hidden' : '${_capitalised(noun)} visible again',
    );
    _refreshQueue(ref);
    if (done == true && context.mounted) Navigator.of(context).pop();
  }

  void _go(BuildContext context, String route, Map<String, String> params) {
    Navigator.of(context).pop();
    context.goNamed(route, pathParameters: params);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final subject = report.subject;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${_capitalised(report.target.noun)} reported: ${report.reason.labelFor(report.target)}',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: scheme.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            'By ${report.reporterName ?? 'a deleted account'} · ${adminDateTime(report.createdAt)}'
            '${report.reportsOnTarget > 1 ? ' · ${report.reportsOnTarget} reports on this' : ''}',
            style: TextStyle(color: muted),
          ),
          if (report.details case final details?) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('"$details"', style: const TextStyle(height: 1.4)),
            ),
          ],
          AdminSection(
            title: 'Reported ${report.target.noun}',
            children: subject.exists
                ? [
                    if (subject.mediaUrl case final url?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    if (subject.text case final text?) Text(text, style: const TextStyle(height: 1.4)),
                    const SizedBox(height: 8),
                    if (subject.authorName != null)
                      AdminInfoRow(
                        label: report.target == ReportTarget.booking ? 'Provider' : 'By',
                        value: subject.authorName!,
                      ),
                    if (subject.rating != null) AdminInfoRow(label: 'Rating', value: '${subject.rating} ★'),
                    if (report.target == ReportTarget.booking) ...[
                      AdminInfoRow(label: 'Status', value: (subject.bookingStatus ?? '—').replaceAll('_', ' ')),
                      AdminInfoRow(
                        label: 'Paid',
                        value: [
                          if (subject.totalCents != null) Formatters.audCents(subject.totalCents!),
                          subject.paymentMethod == 'cash' ? 'cash' : 'in the app',
                        ].join(' · '),
                      ),
                      if (subject.settlementStatus != null)
                        AdminInfoRow(label: "Provider's share", value: subject.settlementStatus!.replaceAll('_', ' ')),
                    ],
                    if (subject.hidden)
                      const AdminInfoRow(label: 'Visibility', value: 'Hidden by Myglo', valueColor: AppTheme.warning),
                  ]
                : [Text('This ${report.target.noun} has since been deleted.', style: TextStyle(color: muted))],
          ),
          if (!report.isOpen)
            AdminSection(
              title: _capitalised(report.status),
              children: [
                if (report.resolvedAt != null) AdminInfoRow(label: 'When', value: adminDateTime(report.resolvedAt!)),
                AdminInfoRow(label: 'Note', value: report.resolution ?? '—'),
              ],
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (report.canHide && subject.exists)
                OutlinedButton.icon(
                  onPressed: () => _setHidden(context, ref, hidden: !subject.hidden),
                  icon: Icon(subject.hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  label: Text(subject.hidden ? 'Show again' : 'Hide ${report.target.noun}'),
                ),
              if (report.target == ReportTarget.booking)
                OutlinedButton.icon(
                  onPressed: () => _go(context, AppRoute.adminPayment.name, {'bookingId': report.targetId}),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Booking & payment'),
                ),
              if (subject.authorId case final authorId?)
                OutlinedButton.icon(
                  onPressed: () => _go(context, AppRoute.adminUser.name, {'userId': authorId}),
                  icon: const Icon(Icons.person_search_outlined),
                  label: Text(report.target == ReportTarget.provider ? 'Their account' : 'Author account'),
                ),
              if (report.reporterId case final reporterId?)
                OutlinedButton.icon(
                  onPressed: () => _go(context, AppRoute.adminUser.name, {'userId': reporterId}),
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Reporter'),
                ),
            ],
          ),
          if (report.isOpen) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _close(context, ref, dismiss: true),
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _close(context, ref, dismiss: false),
                    child: const Text('Resolve'),
                  ),
                ),
              ],
            ),
            if (report.target == ReportTarget.booking) ...[
              const SizedBox(height: 8),
              Text(
                "Closing the last open report on a booking releases the provider's share, unless it's held for "
                'another reason. Refund first from the booking if the client is owed money.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: muted),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
