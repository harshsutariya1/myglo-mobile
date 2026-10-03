import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../providers/provider_profiles/views/screens/edit_provider_profile_screen.dart';
import '../../controllers/discovery_feed_controller.dart';
import 'bento_grid.dart';
import 'discover_tab_body.dart';

/// Providers' Discover: one page of looks posted near their business, as a
/// bento grid.
class NearbyBentoView extends StatelessWidget {
  const NearbyBentoView({super.key, required this.appBar, required this.appBarExtent, required this.onShareLook});

  final Widget appBar;
  final double appBarExtent;
  final VoidCallback onShareLook;

  @override
  Widget build(BuildContext context) {
    return DiscoverTabBody(
      tab: DiscoverTab.nearby,
      appBar: appBar,
      appBarExtent: appBarExtent,
      loading: const SliverBentoSkeleton(),
      header: (state) => _NearbyNotice(fallback: state.nearbyFallback),
      content: (state) => SliverBentoGrid(entries: state.entries, complete: !state.hasMore),
      empty: (_) => DiscoverEmptyState(
        icon: Icons.auto_awesome_outlined,
        title: 'Nothing to discover yet',
        message: 'Looks shared by clients and salons around you will appear here.',
        actionLabel: 'Share a look',
        onAction: onShareLook,
      ),
    );
  }
}

/// What the feed is showing: nearby posts, or recent posts from everywhere
/// and why.
class _NearbyNotice extends StatelessWidget {
  const _NearbyNotice({required this.fallback});

  final NearbyFallback? fallback;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final radiusKm = (AppConfig.nearbyRadiusMetres / 1000).round();

    return switch (fallback) {
      null => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Icon(Icons.near_me_rounded, size: 16, color: scheme.secondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Within $radiusKm km of your business',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: muted),
                ),
              ),
            ],
          ),
        ),
      NearbyFallback.noLocation => _NoticeCard(
          icon: Icons.add_location_alt_outlined,
          title: 'See what’s happening near you',
          message: 'Add your business address and Discover will show looks from clients and salons around you.',
          actionLabel: 'Add address',
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const EditProviderProfileScreen()),
          ),
        ),
      NearbyFallback.nothingNearby => const _NoticeCard(
          icon: Icons.travel_explore_rounded,
          title: 'Nothing nearby yet',
          message: 'Showing the latest looks from across Myglo until people near you start posting.',
        ),
    };
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: scheme.secondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: TextStyle(fontSize: 13.5, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.65)),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: onAction,
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.onSurface,
                        foregroundColor: scheme.surface,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
