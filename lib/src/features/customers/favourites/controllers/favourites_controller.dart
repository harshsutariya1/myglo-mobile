import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../shared/authentication/models/profile_model.dart';
import '../../../shared/authentication/models/user_repository.dart';
import '../models/favourites_repository.dart';

/// The signed-in client's saved providers.
class FavouritesState {
  const FavouritesState({required this.providerIds, required this.canFavourite});

  /// Most recently saved first.
  final List<String> providerIds;

  /// False for providers and signed-out viewers: favourites are client-only.
  final bool canFavourite;

  bool contains(String providerId) => providerIds.contains(providerId);
}

final favouritesProvider = AsyncNotifierProvider<FavouritesController, FavouritesState>(FavouritesController.new);

/// Loads the client's favourites once per session and toggles them
/// optimistically: the heart flips immediately and rolls back if the request
/// fails.
class FavouritesController extends AsyncNotifier<FavouritesState> {
  /// Providers with a save/remove in flight; repeat taps are ignored.
  final Set<String> _pending = {};

  String? _clientId;

  @override
  Future<FavouritesState> build() async {
    final viewer = ref.watch(
      userProfileProvider.select((p) => (id: p.value?.rawUser.id, isClient: p.value?.isCustomer ?? false)),
    );
    _pending.clear();
    _clientId = viewer.isClient ? viewer.id : null;
    final clientId = _clientId;
    if (clientId == null) return const FavouritesState(providerIds: [], canFavourite: false);

    final ids = await ref.read(favouritesRepositoryProvider).getFavouriteProviderIds(clientId);
    return FavouritesState(providerIds: ids, canFavourite: true);
  }

  /// Saves or removes [providerId]. Returns false if the change couldn't be
  /// saved (the previous state is restored).
  Future<bool> setFavourite(String providerId, {required bool favourite}) async {
    final current = state.value;
    final clientId = _clientId;
    if (current == null || !current.canFavourite || clientId == null) return false;
    if (current.contains(providerId) == favourite || _pending.contains(providerId)) return true;

    _pending.add(providerId);
    state = AsyncData(FavouritesState(
      providerIds: favourite
          ? [providerId, ...current.providerIds]
          : current.providerIds.where((id) => id != providerId).toList(),
      canFavourite: true,
    ));
    try {
      final repository = ref.read(favouritesRepositoryProvider);
      if (favourite) {
        await repository.addFavourite(clientId: clientId, providerId: providerId);
      } else {
        await repository.removeFavourite(clientId: clientId, providerId: providerId);
      }
      return true;
    } catch (e, st) {
      AppLogger.w('Failed to ${favourite ? 'save' : 'remove'} favourite $providerId',
          tag: 'Favourites', error: e, stackTrace: st);
      if (ref.mounted) {
        // Undo only this change, keeping any made meanwhile.
        final latest = state.value ?? current;
        state = AsyncData(FavouritesState(
          providerIds: favourite
              ? latest.providerIds.where((id) => id != providerId).toList()
              : _restore(latest.providerIds, providerId, current.providerIds),
          canFavourite: true,
        ));
      }
      return false;
    } finally {
      _pending.remove(providerId);
    }
  }

  Future<bool> toggle(String providerId) {
    final isFavourite = state.value?.contains(providerId) ?? false;
    return setFavourite(providerId, favourite: !isFavourite);
  }

  /// Puts [id] back where it was in [original], relative to the ids still in
  /// [ids].
  static List<String> _restore(List<String> ids, String id, List<String> original) {
    if (ids.contains(id)) return ids;
    final index = original.indexOf(id);
    final before = original.take(index < 0 ? 0 : index).where(ids.contains).length;
    return [...ids.take(before), id, ...ids.skip(before)];
  }
}

/// Public profiles of the client's favourite providers, keyed by id. Refetches
/// when the list changes; the screen orders them using [favouritesProvider].
final favouriteProfilesProvider = FutureProvider.autoDispose<Map<String, ProfileModel>>((ref) async {
  final favourites = await ref.watch(favouritesProvider.future);
  return ref.read(userRepositoryProvider).getPublicProfiles(favourites.providerIds);
});
