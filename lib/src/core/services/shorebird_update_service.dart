import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:restart_app/restart_app.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../config/app_config.dart';
import '../utils/app_logger.dart';

/// Where the over-the-air (Shorebird) update flow is.
///
/// `shorebird.yaml` sets `auto_update: false` and this service does the work
/// instead, so patches are also found on resume and while the app stays open.
/// A patch found by a check downloads silently ([available] → [downloading]);
/// only once it is installed ([readyToRestart]) does the home screen ask for a
/// restart. A patch that is downloaded but not restarted into is applied on
/// the next cold start anyway.
enum ShorebirdUpdatePhase {
  /// Up to date, not checked yet, or the updater isn't in this build (debug
  /// builds and anything not built with `shorebird release`).
  idle,

  /// A newer patch is on the server but isn't downloaded, because the last
  /// download failed. The next check tries again.
  available,

  /// The patch is being downloaded and installed.
  downloading,

  /// The patch is on disk and loads on the next process start. Also used when
  /// the running patch was rolled back and a restart returns to the base
  /// release.
  readyToRestart,

  /// A restart has been requested.
  restarting,
}

/// Why the last step failed, if it did.
enum ShorebirdUpdateError { downloadFailed, restartFailed }

@immutable
class ShorebirdUpdateState {
  const ShorebirdUpdateState({
    this.phase = ShorebirdUpdatePhase.idle,
    this.isChecking = false,
    this.currentPatch,
    this.error,
  });

  final ShorebirdUpdatePhase phase;

  /// A check is in flight. Kept apart from [phase] so a background re-check
  /// doesn't change what is on screen.
  final bool isChecking;

  /// The patch this process is running, or null on the base release.
  final int? currentPatch;

  final ShorebirdUpdateError? error;

  /// Whether the home screens show the update banner: only once a patch is
  /// installed and waiting for a restart.
  bool get needsRestart =>
      phase == ShorebirdUpdatePhase.readyToRestart || phase == ShorebirdUpdatePhase.restarting;

  bool get isBusy =>
      isChecking || phase == ShorebirdUpdatePhase.downloading || phase == ShorebirdUpdatePhase.restarting;

  ShorebirdUpdateState copyWith({
    ShorebirdUpdatePhase? phase,
    bool? isChecking,
    int? currentPatch,
    ShorebirdUpdateError? error,
    bool clearError = false,
  }) {
    return ShorebirdUpdateState(
      phase: phase ?? this.phase,
      isChecking: isChecking ?? this.isChecking,
      currentPatch: currentPatch ?? this.currentPatch,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Relaunches the app so a downloaded patch is loaded.
///
/// A Shorebird patch is only picked up when the native process starts, so
/// this must be a real process restart. Android can do that. iOS has no
/// public API for it (an engine restart keeps the old code loaded, and
/// calling `exit()` goes against Apple's guidelines), so on iOS the user is
/// asked to close and reopen the app instead.
class AppRestarter {
  const AppRestarter();

  bool get canRestartInApp => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Returns whether the restart was started. On success the process exits
  /// shortly after, so callers shouldn't rely on anything running afterwards.
  Future<bool> restart() async {
    if (!canRestartInApp) return false;
    final result = await Restart.restartApp(mode: RestartMode.process);
    if (!result.success) {
      AppLogger.e(
        'App restart failed',
        tag: 'Shorebird',
        error: StateError('Restart failed: ${result.code} ${result.message}'),
        stackTrace: StackTrace.current,
      );
    }
    return result.success;
  }
}

final shorebirdUpdaterProvider = Provider<ShorebirdUpdater>((ref) => ShorebirdUpdater());

final appRestarterProvider = Provider<AppRestarter>((ref) => const AppRestarter());

/// Clock for the check throttle; overridden in tests.
final shorebirdClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final shorebirdUpdateServiceProvider =
    NotifierProvider<ShorebirdUpdateService, ShorebirdUpdateState>(ShorebirdUpdateService.new);

/// Finds, downloads and applies Shorebird patches. Checks are triggered by
/// [ShorebirdUpdateWatcher] (launch, resume and a timer) and by the manual
/// "Check for updates" setting; a patch they find is downloaded straight away.
class ShorebirdUpdateService extends Notifier<ShorebirdUpdateState> {
  late ShorebirdUpdater _updater;
  DateTime? _lastCheckAt;
  bool _reportedCheckFailure = false;
  bool _reportedDownloadFailure = false;

  UpdateTrack get _track => UpdateTrack(AppConfig.shorebirdTrack);

  @override
  ShorebirdUpdateState build() {
    _updater = ref.watch(shorebirdUpdaterProvider);
    _readCurrentPatch();
    return const ShorebirdUpdateState();
  }

  bool get isAvailable => _updater.isAvailable;

  Future<void> _readCurrentPatch() async {
    if (!_updater.isAvailable) {
      AppLogger.d('Shorebird updater not in this build; OTA updates are off.', tag: 'Shorebird');
      return;
    }
    try {
      final patch = await _updater.readCurrentPatch();
      final number = patch?.number;
      AppLogger.i('Running ${number == null ? 'the base release' : 'patch $number'}', tag: 'Shorebird');
      // Lets Sentry issues be filtered by patch, to spot a bad one quickly.
      await Sentry.configureScope((scope) => scope.setTag('shorebird.patch', number?.toString() ?? 'base'));
      if (number != null && ref.mounted) state = state.copyWith(currentPatch: number);
    } catch (e, st) {
      AppLogger.e('Reading the current Shorebird patch failed', tag: 'Shorebird', error: e, stackTrace: st);
    }
  }

  /// Asks the server whether a newer patch exists and, if so, downloads it.
  ///
  /// Background callers leave [force] off, so checks are at least
  /// [AppConfig.appUpdateMinCheckGap] apart. Returns the resulting state.
  Future<ShorebirdUpdateState> checkForUpdate({bool force = false}) async {
    if (!_updater.isAvailable || state.isBusy) return state;
    // Already downloaded: nothing newer matters until the restart.
    if (state.phase == ShorebirdUpdatePhase.readyToRestart) return state;

    final now = ref.read(shorebirdClockProvider)();
    final last = _lastCheckAt;
    if (!force && last != null && now.difference(last) < AppConfig.appUpdateMinCheckGap) return state;
    _lastCheckAt = now;

    state = state.copyWith(isChecking: true);
    try {
      final status = await _updater.checkForUpdate(track: _track);
      if (!ref.mounted) return state;
      AppLogger.i('Update check: ${status.name}', tag: 'Shorebird');
      state = switch (status) {
        UpdateStatus.outdated => state.copyWith(isChecking: false, phase: ShorebirdUpdatePhase.available),
        UpdateStatus.restartRequired =>
          state.copyWith(isChecking: false, phase: ShorebirdUpdatePhase.readyToRestart, clearError: true),
        // Nothing newer, e.g. the patch was pulled from the console.
        UpdateStatus.upToDate || UpdateStatus.unavailable =>
          state.copyWith(isChecking: false, phase: ShorebirdUpdatePhase.idle, clearError: true),
      };
      if (status == UpdateStatus.outdated) await downloadUpdate();
    } catch (e, st) {
      // Usually just a bad connection, and the next check retries. Report the
      // first failure per run so a broken setup (e.g. wrong app_id) still
      // shows up in Sentry without flooding it.
      AppLogger.w('Update check failed', tag: 'Shorebird', error: e, stackTrace: st);
      if (!_reportedCheckFailure) {
        _reportedCheckFailure = true;
        await Sentry.captureException(e, stackTrace: st, withScope: (scope) {
          scope.level = SentryLevel.warning;
          scope.setTag('logger_tag', 'Shorebird');
        });
      }
      if (ref.mounted) state = state.copyWith(isChecking: false);
    }
    return state;
  }

  /// Downloads and installs the available patch in the background. It loads
  /// on the next process start ([restartToApply], or the next cold launch).
  Future<void> downloadUpdate() async {
    if (!_updater.isAvailable || state.phase != ShorebirdUpdatePhase.available) return;
    state = state.copyWith(phase: ShorebirdUpdatePhase.downloading, clearError: true);
    try {
      AppLogger.i('Downloading patch…', tag: 'Shorebird');
      await _updater.update(track: _track);
      // update() also returns quietly when there was nothing to install, so
      // confirm a different patch is now waiting on disk.
      final (current, next) = await (_updater.readCurrentPatch(), _updater.readNextPatch()).wait;
      if (!ref.mounted) return;
      if (current?.number != next?.number) {
        AppLogger.i('Patch ${next?.number} installed; restart to apply', tag: 'Shorebird');
        state = state.copyWith(phase: ShorebirdUpdatePhase.readyToRestart);
      } else {
        AppLogger.w('Update finished without a new patch on disk', tag: 'Shorebird');
        state = state.copyWith(phase: ShorebirdUpdatePhase.idle);
      }
    } on UpdateException catch (e, st) {
      if (!ref.mounted) return;
      if (e.reason == UpdateFailureReason.noUpdate) {
        state = state.copyWith(phase: ShorebirdUpdatePhase.idle);
        return;
      }
      _onDownloadFailed('Patch download failed (${e.reason.name})', e, st);
    } catch (e, st) {
      _onDownloadFailed('Patch download failed', e, st);
    }
  }

  /// Leaves the patch [ShorebirdUpdatePhase.available] so the next check
  /// retries. Silent downloads can fail repeatedly on a bad connection, so
  /// only the first failure per run is sent to Sentry.
  void _onDownloadFailed(String message, Object error, StackTrace stackTrace) {
    AppLogger.e(message, tag: 'Shorebird', error: error, stackTrace: stackTrace, reportToSentry: !_reportedDownloadFailure);
    _reportedDownloadFailure = true;
    if (ref.mounted) {
      state = state.copyWith(phase: ShorebirdUpdatePhase.available, error: ShorebirdUpdateError.downloadFailed);
    }
  }

  /// Restarts into the downloaded patch. Returns false when the app can't
  /// restart itself (iOS, or the restart failed); the caller then asks the
  /// user to reopen the app.
  Future<bool> restartToApply() async {
    if (state.phase != ShorebirdUpdatePhase.readyToRestart) return false;
    final restarter = ref.read(appRestarterProvider);
    if (!restarter.canRestartInApp) return false;

    state = state.copyWith(phase: ShorebirdUpdatePhase.restarting, clearError: true);
    await Sentry.addBreadcrumb(Breadcrumb(category: 'shorebird', message: 'Restarting to apply patch'));
    bool started;
    try {
      started = await restarter.restart();
    } catch (e, st) {
      AppLogger.e('App restart failed', tag: 'Shorebird', error: e, stackTrace: st);
      started = false;
    }
    if (!started && ref.mounted) {
      state = state.copyWith(phase: ShorebirdUpdatePhase.readyToRestart, error: ShorebirdUpdateError.restartFailed);
    }
    return started;
  }
}
