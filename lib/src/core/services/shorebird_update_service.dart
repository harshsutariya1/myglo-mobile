import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import '../utils/app_logger.dart';

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
        final patchNumber = patch?.number.toString();
        AppLogger.i(
          'Shorebird code-push initialized (Patch: ${patchNumber ?? 'base build'})',
          tag: 'Shorebird',
        );
        state = state.copyWith(currentPatchVersion: patchNumber);
      } else {
        AppLogger.d(
          'Shorebird code-push updater is not available on this device/platform.',
          tag: 'Shorebird',
        );
      }
    } catch (e, st) {
      AppLogger.w('Failed reading current patch', tag: 'Shorebird', error: e, stackTrace: st);
    }
  }

  Future<bool> checkForUpdate() async {
    state = state.copyWith(isChecking: true, error: null);
    try {
      if (!_updater.isAvailable) {
        state = state.copyWith(isChecking: false);
        return false;
      }

      AppLogger.d('Checking for code-push updates...', tag: 'Shorebird');
      final status = await _updater.checkForUpdate();
      
      final isAvailable = status == UpdateStatus.outdated;
      final isReady = status == UpdateStatus.restartRequired;

      AppLogger.i(
        'Code-push check completed (Status: $status, UpdateAvailable: $isAvailable, ReadyToInstall: $isReady)',
        tag: 'Shorebird',
      );

      state = state.copyWith(
        isChecking: false,
        isUpdateAvailable: isAvailable,
        isUpdateReadyToInstall: isReady,
      );
      return isAvailable;
    } catch (e, st) {
      AppLogger.e('Error checking for Shorebird update', tag: 'Shorebird', error: e, stackTrace: st);
      state = state.copyWith(isChecking: false, error: e.toString());
      return false;
    }
  }

  Future<void> downloadUpdate() async {
    state = state.copyWith(isDownloading: true, error: null);
    try {
      AppLogger.i('Downloading Shorebird patch...', tag: 'Shorebird');
      await _updater.update();
      AppLogger.i('✅ Shorebird patch downloaded. Restart required to apply.', tag: 'Shorebird');
      state = state.copyWith(
        isDownloading: false,
        isUpdateReadyToInstall: true,
      );
    } on UpdateException catch (e, st) {
      AppLogger.e('Shorebird update exception: ${e.message}', tag: 'Shorebird', error: e, stackTrace: st);
      state = state.copyWith(isDownloading: false, error: e.message);
    } catch (e, st) {
      AppLogger.e('Error downloading Shorebird update', tag: 'Shorebird', error: e, stackTrace: st);
      state = state.copyWith(isDownloading: false, error: e.toString());
    }
  }
}
