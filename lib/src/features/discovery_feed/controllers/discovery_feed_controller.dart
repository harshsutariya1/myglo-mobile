import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../customers/favourites/controllers/favourites_controller.dart';
import '../../shared/authentication/controllers/user_profile_provider.dart';
import '../../shared/authentication/models/profile_model.dart';
import '../../shared/authentication/models/user_repository.dart';
import '../models/post_model.dart';
import '../models/post_repository.dart';

/// The Discover feeds. Clients get [forYou] and [favourites] as tabs;
/// providers get the single [nearby] page.
enum DiscoverTab { forYou, favourites, nearby }

/// Why the [DiscoverTab.nearby] feed is showing recent posts from everywhere
/// instead of nearby ones.
enum NearbyFallback {
  /// The provider hasn't saved a business address.
  noLocation,

  /// Nobody near the provider has posted yet.
  nothingNearby,
}

/// A post with its author's public profile. [author] is null when the
/// account no longer exists or its profile couldn't be loaded.
class FeedEntry {
  const FeedEntry({required this.post, this.author});

  final PostModel post;
  final ProfileModel? author;
}

class DiscoveryFeedState {
  const DiscoveryFeedState({
    required this.entries,
    required this.hasMore,
    this.noFavourites = false,
    this.nearbyFallback,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<FeedEntry> entries;

  /// Whether another page may exist.
  final bool hasMore;

  /// Favourites tab only: the client hasn't saved any providers (as opposed
  /// to saving providers who haven't posted).
  final bool noFavourites;

  /// Nearby tab only: set when showing recent posts from everywhere instead.
  final NearbyFallback? nearbyFallback;

  final bool isLoadingMore;

  /// The last attempt to load the next page failed; scrolling won't retry
  /// on its own until the viewer asks.
  final bool loadMoreFailed;

  DiscoveryFeedState copyWith({
    List<FeedEntry>? entries,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) =>
      DiscoveryFeedState(
        entries: entries ?? this.entries,
        hasMore: hasMore ?? this.hasMore,
        noFavourites: noFavourites,
        nearbyFallback: nearbyFallback,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );
}

final discoveryFeedProvider =
    AsyncNotifierProvider.autoDispose.family<DiscoveryFeedController, DiscoveryFeedState, DiscoverTab>(
  DiscoveryFeedController.new,
);

/// Paged Discover feed. Pages are keyset-paginated on `created_at` so posts
/// arriving mid-scroll never cause repeats.
///
/// - [DiscoverTab.forYou]: every visible post.
/// - [DiscoverTab.favourites]: posts by, or tagging, the client's favourites.
/// - [DiscoverTab.nearby]: other people's posts near the provider's business
///   address, falling back to recent posts everywhere (see [NearbyFallback]).
class DiscoveryFeedController extends AsyncNotifier<DiscoveryFeedState> {
  DiscoveryFeedController(this.tab);

  final DiscoverTab tab;

  /// Favourites tab: the providers whose posts are shown.
  List<String>? _providerIds;

  /// Nearby tab: whether pages come from the nearby query.
  bool _nearby = false;

  /// Nearby tab: the viewer, whose own posts are left out.
  String? _excludeAuthorId;

  int get _pageSize => AppConfig.discoverPageSize;

  @override
  Future<DiscoveryFeedState> build() async {
    // Rebuild when the account changes: visibility (RLS) differs.
    final userId = ref.watch(userProfileProvider.select((p) => p.value?.rawUser.id));
    _providerIds = null;
    _nearby = false;
    _excludeAuthorId = null;

    switch (tab) {
      case DiscoverTab.forYou:
        break;
      case DiscoverTab.favourites:
        final favourites = await ref.watch(favouritesProvider.future);
        if (favourites.providerIds.isEmpty) {
          return const DiscoveryFeedState(entries: [], hasMore: false, noFavourites: true);
        }
        _providerIds = favourites.providerIds;
      case DiscoverTab.nearby:
        _excludeAuthorId = userId;
        final hasLocation = ref.watch(userProfileProvider.select((p) => p.value?.profile.coordinates != null));
        if (hasLocation) {
          _nearby = true;
          final entries = await _fetchPage(before: null);
          if (entries.isNotEmpty) {
            return DiscoveryFeedState(entries: entries, hasMore: entries.length >= _pageSize);
          }
          _nearby = false;
        }
        final entries = await _fetchPage(before: null);
        return DiscoveryFeedState(
          entries: entries,
          hasMore: entries.length >= _pageSize,
          nearbyFallback: hasLocation ? NearbyFallback.nothingNearby : NearbyFallback.noLocation,
        );
    }

    final entries = await _fetchPage(before: null);
    return DiscoveryFeedState(entries: entries, hasMore: entries.length >= _pageSize);
  }

  /// Appends the next page. Safe to call repeatedly while scrolling: it does
  /// nothing while a page is in flight, at the end, or after a failure (until
  /// [retryLoadMore]).
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || state.isLoading || !current.hasMore || current.isLoadingMore || current.loadMoreFailed) {
      return;
    }
    await _loadNext(current);
  }

  /// Retries a failed [loadMore].
  Future<void> retryLoadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore) return;
    await _loadNext(current.copyWith(loadMoreFailed: false));
  }

  Future<void> _loadNext(DiscoveryFeedState current) async {
    state = AsyncData(current.copyWith(isLoadingMore: true, loadMoreFailed: false));
    try {
      final page = await _fetchPage(before: current.entries.isEmpty ? null : current.entries.last.post.createdAt);
      if (!ref.mounted) return;
      final seen = {for (final entry in current.entries) entry.post.id};
      final fresh = page.where((entry) => seen.add(entry.post.id)).toList();
      state = AsyncData(current.copyWith(
        entries: [...current.entries, ...fresh],
        hasMore: page.length >= _pageSize,
        isLoadingMore: false,
      ));
    } catch (_) {
      // Already reported by the repository.
      if (ref.mounted) state = AsyncData(current.copyWith(isLoadingMore: false, loadMoreFailed: true));
    }
  }

  Future<List<FeedEntry>> _fetchPage({required DateTime? before}) async {
    final repository = ref.read(postRepositoryProvider);
    final posts = _nearby
        ? await repository.getNearbyPage(
            limit: _pageSize,
            radiusMetres: AppConfig.nearbyRadiusMetres,
            before: before,
          )
        : await repository.getFeedPage(
            limit: _pageSize,
            before: before,
            providerIds: _providerIds,
            excludeAuthorId: _excludeAuthorId,
          );

    Map<String, ProfileModel> authors;
    try {
      authors = await ref.read(userRepositoryProvider).getPublicProfiles(posts.map((p) => p.authorId));
    } catch (_) {
      // Already reported by the repository. The posts are still worth
      // showing; cards fall back to a generic author label.
      authors = const {};
    }
    return [for (final post in posts) FeedEntry(post: post, author: authors[post.authorId])];
  }
}
