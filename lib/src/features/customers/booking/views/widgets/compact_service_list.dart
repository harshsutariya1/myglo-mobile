import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../providers/provider_profiles/models/service_model.dart';
import 'selectable_service_tile.dart';

/// Text of [CompactListHint].
const String compactListHintText = 'Press and hold a service for more details';

/// Small note above the "All" list explaining that compact rows open their
/// details on long-press, since they have no visible details link.
class CompactListHint extends StatelessWidget {
  const CompactListHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        compactListHintText,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: context.colorScheme.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

/// One category of the "All" tab: a small heading over a single card of
/// compact, divider-separated rows, so the full menu stays short enough to
/// scan.
class CompactServiceGroup extends StatelessWidget {
  const CompactServiceGroup({
    super.key,
    required this.label,
    required this.services,
    required this.isSelected,
    required this.onToggle,
    required this.onShowDetails,
  });

  final String label;
  final List<ServiceModel> services;
  final bool Function(ServiceModel service) isSelected;
  final ValueChanged<ServiceModel> onToggle;
  final ValueChanged<ServiceModel> onShowDetails;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final border = scheme.onSurface.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Semantics(
              header: true,
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < services.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: border),
                  CompactServiceRow(
                    key: ValueKey(services[i].id),
                    service: services[i],
                    selected: isSelected(services[i]),
                    onToggle: () => onToggle(services[i]),
                    onShowDetails: () => onShowDetails(services[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single-line service: name and duration on the left, price and a check on
/// the right. Tap toggles; long-press opens the full details.
class CompactServiceRow extends StatelessWidget {
  const CompactServiceRow({
    super.key,
    required this.service,
    required this.selected,
    required this.onToggle,
    required this.onShowDetails,
  });

  final ServiceModel service;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onShowDetails;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      hint: selected ? 'Double tap to remove' : 'Double tap to add',
      onLongPressHint: 'View details',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: selected ? scheme.primary.withValues(alpha: 0.07) : Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          onLongPress: onShowDetails,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.duration(service.durationMinutes),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  Formatters.aud(service.price),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface),
                ),
                const SizedBox(width: 14),
                SelectionCheck(selected: selected, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
