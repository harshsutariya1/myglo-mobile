import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_preferences.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';
import '../models/service_cities_repository.dart';
import '../models/service_city.dart';

/// Cities clients can browse, with how many providers each has.
final serviceCitiesProvider = FutureProvider.autoDispose<List<ServiceCity>>((ref) {
  return ref.watch(serviceCitiesRepositoryProvider).listCities();
});

/// Where the client asked the home screen to look.
@immutable
sealed class HomeLocationChoice {
  const HomeLocationChoice();

  /// How the choice is kept on the device. Only a city id or "current" is
  /// stored, never a position.
  String encode();

  static HomeLocationChoice? decode(String? value) {
    if (value == null) return null;
    if (value == CurrentLocationChoice._code) return const CurrentLocationChoice();
    if (value.startsWith(CityChoice._prefix)) {
      final id = value.substring(CityChoice._prefix.length);
      if (id.isNotEmpty) return CityChoice(id);
    }
    return null;
  }
}

/// Near wherever the device is.
final class CurrentLocationChoice extends HomeLocationChoice {
  const CurrentLocationChoice();

  static const _code = 'current';

  @override
  String encode() => _code;

  @override
  bool operator ==(Object other) => other is CurrentLocationChoice;

  @override
  int get hashCode => _code.hashCode;
}

/// A city from the curated list.
final class CityChoice extends HomeLocationChoice {
  const CityChoice(this.cityId);

  final String cityId;

  static const _prefix = 'city:';

  @override
  String encode() => '$_prefix$cityId';

  @override
  bool operator ==(Object other) => other is CityChoice && other.cityId == cityId;

  @override
  int get hashCode => cityId.hashCode;
}

/// The client's location choice for the home screen, remembered on this
/// device per account. Null until they pick one.
final homeLocationChoiceProvider =
    NotifierProvider<HomeLocationChoiceController, HomeLocationChoice?>(HomeLocationChoiceController.new);

class HomeLocationChoiceController extends Notifier<HomeLocationChoice?> {
  static const _keyPrefix = 'home_location';

  String? _key;

  @override
  HomeLocationChoice? build() {
    final userId = ref.watch(userProfileProvider.select((p) => p.value?.rawUser.id));
    _key = userId == null ? null : '$_keyPrefix.$userId';
    final key = _key;
    if (key == null) return null;
    return HomeLocationChoice.decode(ref.watch(sharedPreferencesProvider).getString(key));
  }

  Future<void> choose(HomeLocationChoice choice) async {
    state = choice;
    final key = _key;
    if (key == null) return;
    try {
      await ref.read(sharedPreferencesProvider).setString(key, choice.encode());
    } catch (e, st) {
      // Still applies for this session; only the saved copy is stale.
      AppLogger.e('Saving the home location choice failed', tag: 'HomeLocation', error: e, stackTrace: st);
    }
  }
}
