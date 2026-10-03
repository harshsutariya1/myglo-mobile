import 'package:flutter/material.dart';

import '../../controllers/discovery_feed_controller.dart';
import 'bento_grid.dart';
import 'discover_tab_body.dart';

/// Clients' "For you": every recent look as a bento grid.
class DiscoveryGridView extends StatelessWidget {
  const DiscoveryGridView({super.key, required this.onShareLook});

  final VoidCallback onShareLook;

  @override
  Widget build(BuildContext context) {
    return DiscoverTabBody(
      tab: DiscoverTab.forYou,
      loading: const SliverBentoSkeleton(),
      content: (state) => SliverBentoGrid(entries: state.entries, complete: !state.hasMore),
      empty: (_) => DiscoverEmptyState(
        icon: Icons.auto_awesome_outlined,
        title: 'Nothing to discover yet',
        message: 'Fresh looks from salons and clients around the Gold Coast will appear here.',
        actionLabel: 'Share a look',
        onAction: onShareLook,
      ),
    );
  }
}
