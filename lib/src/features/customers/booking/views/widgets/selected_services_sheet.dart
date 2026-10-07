import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../providers/provider_profiles/models/service_catalog.dart';
import '../../../../providers/provider_profiles/models/service_model.dart';
import '../../../../shared/services/views/widgets/service_tile.dart';
import '../../controllers/service_selection_controller.dart';
import '../../models/service_selection.dart';

/// Opens the review sheet listing every service selected from [providerId],
/// with their details, a way to remove each one and the running total.
///
/// The sheet stays in sync with the booking screen underneath and closes by
/// itself once the last service is removed. [onContinue] runs after the
/// sheet has closed.
Future<void> showSelectedServicesSheet(
  BuildContext context, {
  required String providerId,
  required VoidCallback onContinue,
}) async {
  final proceed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.colorScheme.surface,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => SelectedServicesSheet(providerId: providerId),
  );
  if (proceed ?? false) onContinue();
}

/// Body of [showSelectedServicesSheet]. Pops `true` when the client taps
/// Continue.
class SelectedServicesSheet extends ConsumerWidget {
  const SelectedServicesSheet({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(serviceSelectionProvider(providerId));
    final controller = ref.read(selectedServiceIdsProvider(providerId).notifier);

    // Nothing left to review once the last service is removed (or the
    // selection is cleared).
    ref.listen(serviceSelectionProvider(providerId), (previous, next) {
      if (next.isEmpty && (previous?.isNotEmpty ?? false)) Navigator.of(context).maybePop();
    });

    void remove(ServiceModel service) {
      HapticFeedback.selectionClick();
      controller.remove(service.id);
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHeader(count: selection.count, onClear: controller.clear),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              itemCount: selection.count,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final service = selection.services[index];
                return _SelectedServiceRow(
                  key: ValueKey(service.id),
                  service: service,
                  onRemove: () => remove(service),
                );
              },
            ),
          ),
          _SheetFooter(selection: selection, onContinue: () => Navigator.of(context).pop(true)),
        ],
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.count, required this.onClear});

  final int count;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'Your selection',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface),
              ),
            ),
          ),
          if (count > 1)
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                onClear();
              },
              style: TextButton.styleFrom(
                foregroundColor: scheme.secondary,
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              child: const Text('Clear all'),
            ),
        ],
      ),
    );
  }
}

class _SelectedServiceRow extends StatelessWidget {
  const _SelectedServiceRow({super.key, required this.service, required this.onRemove});

  final ServiceModel service;
  final VoidCallback onRemove;

  /// A short line describing what the service involves: its inclusions when
  /// the provider listed them, otherwise the start of its description.
  String get _detail {
    final description = ServiceDescription.parse(service.description);
    if (description.included.isNotEmpty) return 'Includes ${description.included.join(', ')}';
    return description.summary.replaceAll('\n', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final category = service.category?.trim() ?? '';
    final detail = _detail;
    final radius = BorderRadius.circular(ServiceTileMetrics.cardRadius);

    return Dismissible(
      key: ValueKey('dismiss-${service.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: AppTheme.destructive.withValues(alpha: 0.12), borderRadius: radius),
        child: const Icon(Icons.delete_outline_rounded, color: AppTheme.destructive),
      ),
      child: Container(
        padding: const EdgeInsets.all(ServiceTileMetrics.cardPadding),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: radius,
          border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ServiceThumbnail(imageUrl: service.imageUrl, size: 60, radius: ServiceTileMetrics.thumbRadius),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category.isNotEmpty) ...[
                    Text(
                      category.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ServiceTileMetrics.categoryStyle.copyWith(color: scheme.secondary),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    service.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ServiceTileMetrics.titleStyle.copyWith(color: scheme.onSurface),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 15, color: muted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          Formatters.duration(service.durationMinutes),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ServiceTileMetrics.metaStyle.copyWith(color: muted),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        Formatters.aud(service.price),
                        style: ServiceTileMetrics.priceStyle.copyWith(color: scheme.onSurface),
                      ),
                    ],
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, height: 1.35, color: muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Remove ${service.name}',
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: scheme.onSurface.withValues(alpha: 0.06),
                foregroundColor: scheme.onSurface.withValues(alpha: 0.75),
              ),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetFooter extends StatelessWidget {
  const _SheetFooter({required this.selection, required this.onContinue});

  final ServiceSelection selection;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryRow(
            label: 'Duration',
            value: Formatters.duration(selection.totalMinutes),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: muted),
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Total · ${selection.countLabel}',
            value: Formatters.aud(selection.total),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: scheme.onSurface),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.onSurface,
                foregroundColor: scheme.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, required this.style});

  final String label;
  final String value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}
