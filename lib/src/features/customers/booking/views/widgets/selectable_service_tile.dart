import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../providers/provider_profiles/models/service_model.dart';
import '../../../../shared/services/views/widgets/service_tile.dart';

const Duration _animation = Duration(milliseconds: 200);

/// A service the client can tap to add to or remove from their booking.
///
/// Mirrors [ServiceTile]'s layout so the list feels continuous with the
/// provider profile, but the whole card is the toggle: selected cards pick up
/// a brand border, a soft tint and a filled check.
class SelectableServiceTile extends StatelessWidget {
  const SelectableServiceTile({
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
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final radius = BorderRadius.circular(ServiceTileMetrics.cardRadius);

    return Padding(
      padding: ServiceTileMetrics.margin,
      child: Semantics(
        button: true,
        selected: selected,
        hint: selected ? 'Double tap to remove' : 'Double tap to add',
        child: AnimatedContainer(
          duration: _animation,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? scheme.primary.withValues(alpha: 0.06) : scheme.surface,
            borderRadius: radius,
            border: Border.all(
              color: selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.08),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onToggle,
              borderRadius: radius,
              child: Padding(
                padding: const EdgeInsets.all(ServiceTileMetrics.cardPadding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ServiceThumbnail(
                      imageUrl: service.imageUrl,
                      size: ServiceTileMetrics.thumb,
                      radius: ServiceTileMetrics.thumbRadius,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                          const SizedBox(height: 2),
                          _DetailsLink(serviceName: service.name, onPressed: onShowDetails),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: SelectionCheck(selected: selected),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailsLink extends StatelessWidget {
  const _DetailsLink({required this.serviceName, required this.onPressed});

  final String serviceName;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = context.colorScheme.secondary;
    return Semantics(
      label: 'View details for $serviceName',
      button: true,
      excludeSemantics: true,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 6),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('View details'),
            SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Round check that fills with the brand colour when [selected].
class SelectionCheck extends StatelessWidget {
  const SelectionCheck({super.key, required this.selected, this.size = 26});

  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return AnimatedContainer(
      duration: _animation,
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? scheme.primary : Colors.transparent,
        border: Border.all(
          color: selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.25),
          width: 1.6,
        ),
      ),
      child: AnimatedScale(
        duration: _animation,
        curve: Curves.easeOutBack,
        scale: selected ? 1 : 0,
        child: Icon(Icons.check_rounded, size: size * 0.65, color: scheme.onPrimary),
      ),
    );
  }
}
