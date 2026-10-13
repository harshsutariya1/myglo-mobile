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

/// Where a page of the feed comes from.
enum _FeedSource {
  /// Every visible post, optionally filtered (For you, Favourites, and Nearby
  /// for a provider without an address).
  all,

  /// Other people's posts near the provider's business address.
  nearby,

  /// Every other post: what [nearby] leaves out, shown once it runs out.
  beyondNearby,
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
    this.beyondNearbyFrom,
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

  /// Nearby tab only: index in [entries] of the first post from beyond the
  /// nearby radius, set once the nearby posts have run out (equal to the
  /// length of [entries] until the first such post loads). Null while nearby
  /// posts are still being paged, and when there's no address to be near.
  final int? beyondNearbyFrom;

  final bool isLoadingMore;

  /// The last attempt to load the next page failed; scrolling won't retry
  /// on its own until the viewer asks.
  final bool loadMoreFailed;

  DiscoveryFeedState copyWith({
    List<FeedEntry>? entries,
    bool? hasMore,
    int? beyondNearbyFrom,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) =>
      DiscoveryFeedState(
        entries: entries ?? this.entries,
        hasMore: hasMore ?? this.hasMore,
        noFavourites: noFavourites,
        nearbyFallback: nearbyFallback,
        beyondNearbyFrom: beyondNearbyFrom ?? this.beyondNearbyFrom,
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
///   address, then, once those run out, every other post (see
///   [DiscoveryFeedState.beyondNearbyFrom]). Without an address it shows
///   recent posts everywhere (see [NearbyFallback]).
class DiscoveryFeedController extends AsyncNotifier<DiscoveryFeedState> {
  DiscoveryFeedController(this.tab);

  final DiscoverTab tab;

  /// Favourites tab: the providers whose posts are shown.
  List<String>? _providerIds;

  /// Nearby tab: whether the provider has an address, so pages come from the
  /// nearby query and then the beyond-nearby one.
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
        if (!hasLocation) {
          final entries = await _fetchPage(_FeedSource.all, before: null);
          return DiscoveryFeedState(
            entries: entries,
            hasMore: entries.length >= _pageSize,
            nearbyFallback: NearbyFallback.noLocation,
          );
        }
        _nearby = true;
        final nearby = await _fetchPage(_FeedSource.nearby, before: null);
        final firstPage = DiscoveryFeedState(entries: nearby, hasMore: true);
        if (nearby.length >= _pageSize) return firstPage;
        // The nearby posts ran out on the first page: carry straight on with
        // the rest so the page isn't left short.
        return _continueBeyondNearby(
          firstPage,
          fallback: nearby.isEmpty ? NearbyFallback.nothingNearby : null,
          // Nothing to show without them, so let the error state take over.
          rethrowWhenEmpty: true,
        );
    }

    final entries = await _fetchPage(_FeedSource.all, before: null);
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
    final source = _sourceFor(current);
    try {
      final page = await _fetchPage(source, before: _cursorFor(current, source));
      if (!ref.mounted) return;
      var next = current.copyWith(
        entries: _appendUnseen(current.entries, page),
        hasMore: page.length >= _pageSize,
        isLoadingMore: false,
      );
      if (source == _FeedSource.nearby && page.length < _pageSize) {
        next = await _continueBeyondNearby(next.copyWith(hasMore: true));
        if (!ref.mounted) return;
      }
      state = AsyncData(next);
    } catch (_) {
      // Already reported by the repository.
      if (ref.mounted) state = AsyncData(current.copyWith(isLoadingMore: false, loadMoreFailed: true));
    }
  }

  /// Marks where the posts from beyond the nearby radius start in [current]
  /// and appends their first page. If that page fails the nearby posts stay
  /// on screen with an inline retry (see [retryLoadMore]), unless there are
  /// none and [rethrowWhenEmpty] is set.
  Future<DiscoveryFeedState> _continueBeyondNearby(
    DiscoveryFeedState current, {
    NearbyFallback? fallback,
    bool rethrowWhenEmpty = false,
  }) async {
    final marked = DiscoveryFeedState(
      entries: current.entries,
      hasMore: true,
      nearbyFallback: fallback ?? current.nearbyFallback,
      beyondNearbyFrom: current.entries.length,
    );
    try {
      final page = await _fetchPage(_FeedSource.beyondNearby, before: null);
      return marked.copyWith(entries: _appendUnseen(marked.entries, page), hasMore: page.length >= _pageSize);
    } catch (_) {
      // Already reported by the repository.
      if (rethrowWhenEmpty && marked.entries.isEmpty) rethrow;
      return marked.copyWith(loadMoreFailed: true);
    }
  }

  _FeedSource _sourceFor(DiscoveryFeedState current) {
    if (!_nearby) return _FeedSource.all;
    return current.beyondNearbyFrom == null ? _FeedSource.nearby : _FeedSource.beyondNearby;
  }

  /// The oldest post already shown from [source]: each source is paged
  /// independently, so the first beyond-nearby page starts from the top.
  DateTime? _cursorFor(DiscoveryFeedState current, _FeedSource source) {
    final from = source == _FeedSource.beyondNearby ? current.beyondNearbyFrom! : 0;
    return current.entries.length > from ? current.entries.last.post.createdAt : null;
  }

  /// [entries] followed by the posts in [page] not already among them (a post
  /// can reappear if it's edited, or its author moves, between pages).
  static List<FeedEntry> _appendUnseen(List<FeedEntry> entries, List<FeedEntry> page) {
    final seen = {for (final entry in entries) entry.post.id};
    return [...entries, ...page.where((entry) => seen.add(entry.post.id))];
  }

  Future<List<FeedEntry>> _fetchPage(_FeedSource source, {required DateTime? before}) async {
    final repository = ref.read(postRepositoryProvider);
    final posts = switch (source) {
      _FeedSource.nearby => await repository.getNearbyPage(
          limit: _pageSize,
          radiusMetres: AppConfig.nearbyRadiusMetres,
          before: before,
        ),
      _FeedSource.beyondNearby => await repository.getBeyondNearbyPage(
          limit: _pageSize,
          radiusMetres: AppConfig.nearbyRadiusMetres,
          before: before,
        ),
      _FeedSource.all => await repository.getFeedPage(
          limit: _pageSize,
          before: before,
          providerIds: _providerIds,
          excludeAuthorId: _excludeAuthorId,
        ),
    };

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
