import 'package:flutter/material.dart';

import '../../controllers/discovery_feed_controller.dart';
import 'bento_grid.dart';
import 'discover_tab_body.dart';

/// Clients' "Favourites": a bento grid of posts by, or tagging, the
/// providers they've saved.
class FavouritesFeedView extends StatelessWidget {
  const FavouritesFeedView({super.key, required this.onBrowseForYou});

  /// Switches to the "For you" tab (from the empty state).
  final VoidCallback onBrowseForYou;

  @override
  Widget build(BuildContext context) {
    return DiscoverTabBody(
      tab: DiscoverTab.favourites,
      loading: const SliverBentoSkeleton(),
      content: (state) => SliverBentoGrid(entries: state.entries, complete: !state.hasMore),
      empty: (state) => state.noFavourites
          ? DiscoverEmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Save the salons you love',
              message: "Tap the heart on a provider's profile and their latest work will show up here.",
              actionLabel: 'Explore For you',
              onAction: onBrowseForYou,
            )
          : DiscoverEmptyState(
              icon: Icons.hourglass_empty_rounded,
              title: 'No posts yet',
              message: "Your favourites haven't shared anything yet. Check back soon.",
              actionLabel: 'Explore For you',
              onAction: onBrowseForYou,
            ),
    );
  }
}
