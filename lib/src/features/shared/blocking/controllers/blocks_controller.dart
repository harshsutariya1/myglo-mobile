import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../customers/explore/controllers/map_providers_controller.dart';
import '../../../customers/explore/controllers/provider_search_controller.dart';
import '../../../customers/home/controllers/home_controller.dart';
import '../../../discovery_feed/controllers/discovery_feed_controller.dart';
import '../../../discovery_feed/controllers/post_comments_controller.dart';
import '../models/blocked_user.dart';
import '../models/blocks_repository.dart';

/// The signed-in user's blocked accounts, newest first.
final blockedUsersProvider = FutureProvider.autoDispose<List<BlockedUser>>(
  (ref) => ref.watch(blocksRepositoryProvider).list(),
);

final blockActionsProvider = Provider<BlockActions>(BlockActions.new);

/// Blocks and unblocks, then reloads everything a block changes: feeds,
/// comments, provider search, the map and the client home list.
class BlockActions {
  BlockActions(this._ref);

  final Ref _ref;

  /// Throws [BlockFailure].
  Future<void> block(String userId) async {
    await _ref.read(blocksRepositoryProvider).block(userId);
    _refresh();
  }

  /// Throws [BlockFailure].
  Future<void> unblock(String userId) async {
    await _ref.read(blocksRepositoryProvider).unblock(userId);
    _refresh();
  }

  void _refresh() {
    _ref
      ..invalidate(blockedUsersProvider)
      ..invalidate(discoveryFeedProvider)
      ..invalidate(postCommentsProvider)
      ..invalidate(homeFeedProvider)
      ..invalidate(mapProvidersProvider)
      ..invalidate(providerSearchProvider);
  }
}
