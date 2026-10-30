import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/admin_controllers.dart';
import '../models/admin_models.dart';
import 'widgets/admin_widgets.dart';

/// Every change an admin has made, newest first, optionally for one record.
/// The log is append-only on the server; nobody can edit or delete it.
class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key, this.filter = const AuditFilter()});

  final AuditFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final log = ref.watch(auditLogProvider(filter));
    return Scaffold(
      appBar: AppBar(title: Text(filter.targetId == null ? 'Audit log' : 'Admin history')),
      body: switch (log) {
        AsyncData(:final value) when value.items.isEmpty => Center(
            child: Text('No admin changes yet.', style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6))),
          ),
        AsyncData(:final value) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(auditLogProvider(filter)),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) {
                  ref.read(auditLogProvider(filter).notifier).loadMore();
                }
                return false;
              },
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: value.items.length + (value.hasMore ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  if (index == value.items.length) {
                    return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                  }
                  final entry = value.items[index];
                  return ListTile(
                    title: Text(describeAuditAction(entry.action)),
                    subtitle: Text(
                      [
                        '${entry.actor} · ${adminDateTime(entry.createdAt)}',
                        if (entry.reason != null) '"${entry.reason}"',
                      ].join('\n'),
                    ),
                    isThreeLine: entry.reason != null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showEntry(context, entry),
                  );
                },
              ),
            ),
          ),
        AsyncError(:final error) => AdminErrorView(error: error, onRetry: () => ref.invalidate(auditLogProvider(filter))),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  void _showEntry(BuildContext context, AuditEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final scheme = context.colorScheme;
        final changes = entry.changedFields;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(
                describeAuditAction(entry.action),
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: scheme.onSurface),
              ),
              const SizedBox(height: 12),
              AdminInfoRow(label: 'By', value: '${entry.actor}${entry.adminEmail == null ? '' : '\n${entry.adminEmail}'}'),
              AdminInfoRow(label: 'When', value: adminDateTime(entry.createdAt)),
              if (entry.reason != null) AdminInfoRow(label: 'Reason', value: entry.reason!),
              if (entry.targetType != null)
                AdminInfoRow(label: 'Record', value: '${entry.targetType}${entry.targetId == null ? '' : '\n${entry.targetId}'}'),
              if (changes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Changes', style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface)),
                const SizedBox(height: 6),
                for (final (field, before, after) in changes)
                  AdminInfoRow(label: field.replaceAll('_', ' '), value: '${before ?? '—'}  →  ${after ?? '—'}'),
              ] else if (entry.after != null) ...[
                const SizedBox(height: 16),
                Text('Details', style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface)),
                const SizedBox(height: 6),
                SelectableText('${entry.after}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A readable label for an audit action key such as `platform_settings.update`.
String describeAuditAction(String action) => switch (action) {
      'platform_settings.update' => 'Changed platform settings',
      'service_city.create' => 'Added a city',
      'service_city.update' => 'Edited a city',
      'service_city.reorder' => 'Reordered cities',
      _ => action.replaceAll('_', ' ').replaceAll('.', ': '),
    };
