import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../customers/favourites/controllers/favourites_controller.dart';
import '../../../customers/provider_profile/views/widgets/section_states.dart';
import '../../controllers/discovery_feed_controller.dart';

/// Remaining scroll distance at which the next page starts loading, so it
/// usually arrives before the viewer reaches the end.
const double _loadMoreThreshold = 800;

/// Shared shell for a Discover feed: keeps its scroll position and data
/// while another tab is shown, offers pull-to-refresh, loads more near the
/// end, and renders the loading, error, empty and end-of-feed states around
/// the feed's own content.
///
/// Without an [appBar] it expects to be a tab body inside the screen's
/// [NestedScrollView]; with one it is a standalone page.
class DiscoverTabBody extends ConsumerStatefulWidget {
  const DiscoverTabBody({
    super.key,
    required this.tab,
    required this.loading,
    required this.content,
    required this.empty,
    this.header,
    this.appBar,
    this.appBarExtent = 0,
  });

  final DiscoverTab tab;

  /// Skeleton sliver shown on first load.
  final Widget loading;

  /// Sliver for the loaded entries (never called when there are none).
  final Widget Function(DiscoveryFeedState state) content;

  /// Shown when the first page is empty.
  final Widget Function(DiscoveryFeedState state) empty;

  /// Optional box above the content or empty state once loaded (e.g. a notice
  /// about what the feed is showing).
  final Widget? Function(DiscoveryFeedState state)? header;

  /// Pinned app bar sliver for a standalone page.
  final Widget? appBar;

  /// Height of [appBar] when pinned, so the refresh spinner appears below it.
  final double appBarExtent;

  @override
  ConsumerState<DiscoverTabBody> createState() => _DiscoverTabBodyState();
}

class _DiscoverTabBodyState extends ConsumerState<DiscoverTabBody> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical && notification.metrics.extentAfter < _loadMoreThreshold) {
      ref.read(discoveryFeedProvider(widget.tab).notifier).loadMore();
    }
    return false;
  }

  /// Reloads the feed, and on Favourites the saved list it's built from (it
  /// may have changed on another device, or failed to load).
  void _reload() {
    if (widget.tab == DiscoverTab.favourites) ref.invalidate(favouritesProvider);
    ref.invalidate(discoveryFeedProvider(widget.tab));
  }

  Future<void> _refresh() async {
    HapticFeedback.mediumImpact();
    _reload();
    try {
      await ref.read(discoveryFeedProvider(widget.tab).future);
    } catch (_) {
      // The error state is rendered below; the repository already reported it.
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feed = ref.watch(discoveryFeedProvider(widget.tab));
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final appBar = widget.appBar;

    final header = feed.value == null ? null : widget.header?.call(feed.value!);
    final slivers = switch (feed) {
      AsyncValue(:final value?, hasValue: true) when value.entries.isEmpty => [
          if (header != null) SliverToBoxAdapter(child: header),
          SliverFillRemaining(hasScrollBody: false, child: Center(child: widget.empty(value))),
        ],
      AsyncValue(:final value?, hasValue: true) => [
          if (header != null) SliverToBoxAdapter(child: header),
          widget.content(value),
          SliverToBoxAdapter(child: _FeedFooter(state: value, tab: widget.tab)),
        ],
      AsyncValue(:final error?) => [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: SectionErrorView(
                title: widget.tab == DiscoverTab.favourites ? "Your favourites didn't load" : "Discover didn't load",
                message: describeLoadError(error, subject: 'new posts'),
                onRetry: _reload,
              ),
            ),
          ),
        ],
      _ => [widget.loading],
    };

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: RefreshIndicator.adaptive(
        onRefresh: _refresh,
        color: context.colorScheme.primary,
        // Sit the spinner below the pinned header rather than under it.
        edgeOffset: appBar != null
            ? widget.appBarExtent
            : NestedScrollView.sliverOverlapAbsorberHandleFor(context).layoutExtent ?? 0,
        child: CustomScrollView(
          key: PageStorageKey<DiscoverTab>(widget.tab),
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            appBar ?? SliverOverlapInjector(handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context)),
            ...slivers,
            SliverToBoxAdapter(child: SizedBox(height: bottomInset + 24)),
          ],
        ),
      ),
    );
  }
}

/// Spinner while the next page loads, an inline retry when it failed, or a
/// quiet end-of-feed marker.
class _FeedFooter extends ConsumerWidget {
  const _FeedFooter({required this.state, required this.tab});

  final DiscoveryFeedState state;
  final DiscoverTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.5);

    if (state.isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2.4, valueColor: AlwaysStoppedAnimation(scheme.primary)),
          ),
        ),
      );
    }
    if (state.loadMoreFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text("Couldn't load more posts", style: TextStyle(fontSize: 13.5, color: muted)),
            TextButton.icon(
              onPressed: () => ref.read(discoveryFeedProvider(tab).notifier).retryLoadMore(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: TextButton.styleFrom(foregroundColor: scheme.onSurface),
            ),
          ],
        ),
      );
    }
    if (!state.hasMore) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 8),
        child: Row(
          children: [
            Expanded(child: Divider(color: scheme.onSurface.withValues(alpha: 0.08))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 16, color: muted),
                  const SizedBox(width: 6),
                  Text(
                    "You're all caught up",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: muted),
                  ),
                ],
              ),
            ),
            Expanded(child: Divider(color: scheme.onSurface.withValues(alpha: 0.08))),
          ],
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}

/// Empty-state panel with an optional call to action.
class DiscoverEmptyState extends StatelessWidget {
  const DiscoverEmptyState({
    super.key,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionEmptyView(icon: icon, title: title, message: message),
        if (actionLabel != null && onAction != null)
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.onSurface,
              foregroundColor: scheme.surface,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            child: Text(actionLabel!),
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}
