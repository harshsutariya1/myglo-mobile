import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'dart:developer' as developer;

part 'shorebird_update_service.g.dart';

class ShorebirdUpdateState {
  final bool isChecking;
  final bool isUpdateAvailable;
  final bool isDownloading;
  final bool isUpdateReadyToInstall;
  final String? currentPatchVersion;
  final String? error;

  const ShorebirdUpdateState({
    this.isChecking = false,
    this.isUpdateAvailable = false,
    this.isDownloading = false,
    this.isUpdateReadyToInstall = false,
    this.currentPatchVersion,
    this.error,
  });

  ShorebirdUpdateState copyWith({
    bool? isChecking,
    bool? isUpdateAvailable,
    bool? isDownloading,
    bool? isUpdateReadyToInstall,
    String? currentPatchVersion,
    String? error,
  }) {
    return ShorebirdUpdateState(
      isChecking: isChecking ?? this.isChecking,
      isUpdateAvailable: isUpdateAvailable ?? this.isUpdateAvailable,
      isDownloading: isDownloading ?? this.isDownloading,
      isUpdateReadyToInstall:
          isUpdateReadyToInstall ?? this.isUpdateReadyToInstall,
      currentPatchVersion: currentPatchVersion ?? this.currentPatchVersion,
      error: error,
    );
  }
}

@riverpod
class ShorebirdUpdateService extends _$ShorebirdUpdateService {
  final ShorebirdUpdater _updater = ShorebirdUpdater();

  @override
  ShorebirdUpdateState build() {
    _init();
    return const ShorebirdUpdateState();
  }

  Future<void> _init() async {
    try {
      if (_updater.isAvailable) {
        final patch = await _updater.readCurrentPatch();
        state = state.copyWith(currentPatchVersion: patch?.number.toString());
      }
    } catch (e) {
      developer.log('Error getting current patch number: $e');
    }
  }

  Future<bool> checkForUpdate() async {
    state = state.copyWith(isChecking: true, error: null);
    try {
      if (!_updater.isAvailable) {
        state = state.copyWith(isChecking: false);
        return false;
      }

      final status = await _updater.checkForUpdate();
      
      final isAvailable = status == UpdateStatus.outdated;
      final isReady = status == UpdateStatus.restartRequired;

      state = state.copyWith(
        isChecking: false,
        isUpdateAvailable: isAvailable,
        isUpdateReadyToInstall: isReady,
      );
      return isAvailable;
    } catch (e) {
      developer.log('Error checking for Shorebird update: $e');
      state = state.copyWith(isChecking: false, error: e.toString());
      return false;
    }
  }

  Future<void> downloadUpdate() async {
    state = state.copyWith(isDownloading: true, error: null);
    try {
      await _updater.update();
      state = state.copyWith(
        isDownloading: false,
        isUpdateReadyToInstall: true,
      );
    } on UpdateException catch (e) {
      developer.log('Update exception: ${e.message}');
      state = state.copyWith(isDownloading: false, error: e.message);
    } catch (e) {
      developer.log('Error downloading Shorebird update: $e');
      state = state.copyWith(isDownloading: false, error: e.toString());
    }
  }
}
