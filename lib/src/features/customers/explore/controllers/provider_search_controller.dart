import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/location/device_location.dart';
import '../../../../core/location/geo_point.dart';
import '../../../../core/services/app_preferences.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';
import '../models/explore_repository.dart';
import '../models/provider_listing.dart';

/// The search box and what it found.
class ProviderSearchState {
  const ProviderSearchState({this.query = '', this.results = const AsyncData([])});

  /// Trimmed text being searched for.
  final String query;
  final AsyncValue<List<ProviderListing>> results;

  /// Too short to search: show suggestions instead of results.
  bool get isIdle => query.length < AppConfig.searchMinLength;

  ProviderSearchState copyWith({String? query, AsyncValue<List<ProviderListing>>? results}) =>
      ProviderSearchState(query: query ?? this.query, results: results ?? this.results);
}

final providerSearchProvider =
    NotifierProvider.autoDispose<ProviderSearchController, ProviderSearchState>(ProviderSearchController.new);

/// Searches as the client types: waits for a pause in typing, and drops
/// answers to anything but the latest query so results never jump back.
class ProviderSearchController extends Notifier<ProviderSearchState> {
  static const Duration debounce = Duration(milliseconds: 300);

  Timer? _timer;
  int _sequence = 0;

  @override
  ProviderSearchState build() {
    ref.onDispose(() => _timer?.cancel());
    return const ProviderSearchState();
  }

  /// Called on every keystroke.
  void setQuery(String text) {
    final query = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (query == state.query && !state.results.hasError) return;
    _timer?.cancel();
    _sequence++;
    if (query.length < AppConfig.searchMinLength) {
      state = ProviderSearchState(query: query);
      return;
    }
    state = state.copyWith(query: query, results: const AsyncLoading<List<ProviderListing>>());
    _timer = Timer(debounce, () => _run(query));
  }

  /// Searches straight away (keyboard "search" button, a suggestion chip).
  Future<void> submit(String text) async {
    final query = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    _timer?.cancel();
    _sequence++;
    if (query.length < AppConfig.searchMinLength) {
      state = ProviderSearchState(query: query);
      return;
    }
    state = state.copyWith(query: query, results: const AsyncLoading<List<ProviderListing>>());
    await _run(query);
  }

  Future<void> retry() => submit(state.query);

  Future<void> _run(String query) async {
    final sequence = ++_sequence;
    try {
      final near = await _nearby();
      final results = await ref.read(exploreRepositoryProvider).search(query, near: near);
      if (!ref.mounted || sequence != _sequence) return;
      state = ProviderSearchState(query: query, results: AsyncData(results));
    } catch (e, st) {
      if (!ref.mounted || sequence != _sequence) return;
      state = ProviderSearchState(query: query, results: AsyncError(e, st));
    }
  }

  /// Where the client is, only if they've already allowed location; a
  /// search never prompts for it.
  Future<GeoPoint?> _nearby() async {
    try {
      return await ref.read(passiveLocationProvider.future).timeout(const Duration(seconds: 3));
    } catch (_) {
      return null;
    }
  }
}

/// Searches this account made on this device, newest first.
final recentSearchesProvider =
    NotifierProvider.autoDispose<RecentSearchesController, List<String>>(RecentSearchesController.new);

class RecentSearchesController extends Notifier<List<String>> {
  static const _keyPrefix = 'recent_searches';

  String? get _key {
    final userId = ref.read(userProfileProvider).value?.rawUser.id;
    return userId == null ? null : '$_keyPrefix.$userId';
  }

  @override
  List<String> build() {
    final userId = ref.watch(userProfileProvider.select((p) => p.value?.rawUser.id));
    if (userId == null) return const [];
    return ref.watch(sharedPreferencesProvider).getStringList('$_keyPrefix.$userId') ?? const [];
  }

  Future<void> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < AppConfig.searchMinLength) return;
    await _save([
      trimmed,
      for (final existing in state)
        if (existing.toLowerCase() != trimmed.toLowerCase()) existing,
    ].take(AppConfig.recentSearchesMax).toList());
  }

  Future<void> remove(String query) => _save([for (final existing in state) if (existing != query) existing]);

  Future<void> clear() => _save(const []);

  Future<void> _save(List<String> searches) async {
    state = searches;
    final key = _key;
    if (key == null) return;
    try {
      await ref.read(sharedPreferencesProvider).setStringList(key, searches);
    } catch (e, st) {
      // Still shown for this session; only the device copy is stale.
      AppLogger.e('Saving recent searches failed', tag: 'RecentSearches', error: e, stackTrace: st);
    }
  }
}
