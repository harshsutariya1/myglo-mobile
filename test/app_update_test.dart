import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myglo/src/core/config/app_config.dart';
import 'package:myglo/src/core/services/shorebird_update_service.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/core/widgets/app_update_banner.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Longer than the banner's expand animation.
const _expand = Duration(milliseconds: 300);

class _MockUpdater extends Mock implements ShorebirdUpdater {}

class _FakeRestarter implements AppRestarter {
  _FakeRestarter({this.canRestartInApp = true, this.succeeds = true});

  @override
  final bool canRestartInApp;
  final bool succeeds;
  int restarts = 0;

  @override
  Future<bool> restart() async {
    restarts++;
    return succeeds;
  }
}

void main() {
  late _MockUpdater updater;
  late _FakeRestarter restarter;
  late DateTime now;

  setUpAll(() => registerFallbackValue(UpdateTrack.stable));

  setUp(() {
    updater = _MockUpdater();
    restarter = _FakeRestarter();
    now = DateTime(2026, 10, 14, 9);
    when(() => updater.isAvailable).thenReturn(true);
    when(() => updater.readCurrentPatch()).thenAnswer((_) async => null);
    when(() => updater.readNextPatch()).thenAnswer((_) async => null);
  });

  List<Override> overrides() => [
        shorebirdUpdaterProvider.overrideWithValue(updater),
        appRestarterProvider.overrideWithValue(restarter),
        shorebirdClockProvider.overrideWithValue(() => now),
      ];

  void stubCheck(UpdateStatus status) {
    when(() => updater.checkForUpdate(track: any(named: 'track'))).thenAnswer((_) async => status);
  }

  void stubSuccessfulDownload({int patch = 1}) {
    when(() => updater.update(track: any(named: 'track'))).thenAnswer((_) async {
      when(() => updater.readNextPatch()).thenAnswer((_) async => Patch(number: patch));
    });
  }

  group('ShorebirdUpdateService', () {
    ProviderContainer container() {
      final c = ProviderContainer.test(overrides: overrides());
      c.read(shorebirdUpdateServiceProvider);
      return c;
    }

    test('does nothing when the build has no updater', () async {
      when(() => updater.isAvailable).thenReturn(false);
      final c = container();

      final state = await c.read(shorebirdUpdateServiceProvider.notifier).checkForUpdate(force: true);

      expect(state.phase, ShorebirdUpdatePhase.idle);
      verifyNever(() => updater.checkForUpdate(track: any(named: 'track')));
    });

    test('reads the running patch number', () async {
      when(() => updater.readCurrentPatch()).thenAnswer((_) async => const Patch(number: 3));
      final c = container();
      await pumpEventQueue();

      expect(c.read(shorebirdUpdateServiceProvider).currentPatch, 3);
    });

    void stubFailedDownload() {
      when(() => updater.update(track: any(named: 'track'))).thenThrow(
        const UpdateException(message: 'network', reason: UpdateFailureReason.downloadFailed),
      );
    }

    test('a newer patch downloads silently, then asks for a restart', () async {
      stubCheck(UpdateStatus.outdated);
      stubSuccessfulDownload(patch: 2);
      final c = container();

      await c.read(shorebirdUpdateServiceProvider.notifier).checkForUpdate();

      final state = c.read(shorebirdUpdateServiceProvider);
      expect(state.phase, ShorebirdUpdatePhase.readyToRestart);
      expect(state.needsRestart, isTrue);
      expect(state.isChecking, isFalse);
      verify(() => updater.checkForUpdate(track: UpdateTrack(AppConfig.shorebirdTrack))).called(1);
      verify(() => updater.update(track: UpdateTrack(AppConfig.shorebirdTrack))).called(1);
    });

    test('nothing asks for attention while the patch downloads', () async {
      stubCheck(UpdateStatus.outdated);
      final download = Completer<void>();
      when(() => updater.update(track: any(named: 'track'))).thenAnswer((_) => download.future);
      final c = container();

      final check = c.read(shorebirdUpdateServiceProvider.notifier).checkForUpdate();
      await pumpEventQueue();
      expect(c.read(shorebirdUpdateServiceProvider).phase, ShorebirdUpdatePhase.downloading);
      expect(c.read(shorebirdUpdateServiceProvider).needsRestart, isFalse);

      when(() => updater.readNextPatch()).thenAnswer((_) async => const Patch(number: 1));
      download.complete();
      await check;
      expect(c.read(shorebirdUpdateServiceProvider).needsRestart, isTrue);
    });

    test('up to date clears a pending update, e.g. after a patch is pulled', () async {
      stubCheck(UpdateStatus.outdated);
      stubFailedDownload();
      final c = container();
      final service = c.read(shorebirdUpdateServiceProvider.notifier);
      await service.checkForUpdate();

      stubCheck(UpdateStatus.upToDate);
      await service.checkForUpdate(force: true);

      final state = c.read(shorebirdUpdateServiceProvider);
      expect(state.phase, ShorebirdUpdatePhase.idle);
      expect(state.error, isNull);
    });

    test('a patch already on disk (or a rollback) goes straight to restart', () async {
      stubCheck(UpdateStatus.restartRequired);
      final c = container();

      await c.read(shorebirdUpdateServiceProvider.notifier).checkForUpdate();

      expect(c.read(shorebirdUpdateServiceProvider).phase, ShorebirdUpdatePhase.readyToRestart);
      verifyNever(() => updater.update(track: any(named: 'track')));
    });

    test('background checks are throttled, manual ones are not', () async {
      stubCheck(UpdateStatus.upToDate);
      final c = container();
      final service = c.read(shorebirdUpdateServiceProvider.notifier);

      await service.checkForUpdate();
      await service.checkForUpdate();
      verify(() => updater.checkForUpdate(track: any(named: 'track'))).called(1);

      await service.checkForUpdate(force: true);
      verify(() => updater.checkForUpdate(track: any(named: 'track'))).called(1);

      now = now.add(AppConfig.appUpdateMinCheckGap);
      await service.checkForUpdate();
      verify(() => updater.checkForUpdate(track: any(named: 'track'))).called(1);
    });

    test('a failed check keeps the current state and downloads nothing', () async {
      stubCheck(UpdateStatus.outdated);
      stubFailedDownload();
      final c = container();
      final service = c.read(shorebirdUpdateServiceProvider.notifier);
      await service.checkForUpdate();

      when(() => updater.checkForUpdate(track: any(named: 'track'))).thenThrow(Exception('offline'));
      await service.checkForUpdate(force: true);

      final state = c.read(shorebirdUpdateServiceProvider);
      expect(state.phase, ShorebirdUpdatePhase.available);
      expect(state.isChecking, isFalse);
      verify(() => updater.update(track: any(named: 'track'))).called(1);
    });

    test('a failed download is retried by the next check', () async {
      stubCheck(UpdateStatus.outdated);
      stubFailedDownload();
      final c = container();
      final service = c.read(shorebirdUpdateServiceProvider.notifier);
      await service.checkForUpdate();

      final failed = c.read(shorebirdUpdateServiceProvider);
      expect(failed.phase, ShorebirdUpdatePhase.available);
      expect(failed.error, ShorebirdUpdateError.downloadFailed);
      expect(failed.needsRestart, isFalse);

      stubSuccessfulDownload();
      now = now.add(AppConfig.appUpdateMinCheckGap);
      await service.checkForUpdate();

      final retried = c.read(shorebirdUpdateServiceProvider);
      expect(retried.phase, ShorebirdUpdatePhase.readyToRestart);
      expect(retried.error, isNull);
    });

    test('a download with nothing new to install stays quiet', () async {
      stubCheck(UpdateStatus.outdated);
      when(() => updater.update(track: any(named: 'track'))).thenAnswer((_) async {});
      final c = container();

      await c.read(shorebirdUpdateServiceProvider.notifier).checkForUpdate();

      expect(c.read(shorebirdUpdateServiceProvider).phase, ShorebirdUpdatePhase.idle);
    });

    test('restart relaunches the app', () async {
      stubCheck(UpdateStatus.restartRequired);
      final c = container();
      final service = c.read(shorebirdUpdateServiceProvider.notifier);
      await service.checkForUpdate();

      final started = await service.restartToApply();

      expect(started, isTrue);
      expect(restarter.restarts, 1);
      expect(c.read(shorebirdUpdateServiceProvider).phase, ShorebirdUpdatePhase.restarting);
    });

    test('a failed restart falls back to asking the user', () async {
      restarter = _FakeRestarter(succeeds: false);
      stubCheck(UpdateStatus.restartRequired);
      final c = container();
      final service = c.read(shorebirdUpdateServiceProvider.notifier);
      await service.checkForUpdate();

      expect(await service.restartToApply(), isFalse);

      final state = c.read(shorebirdUpdateServiceProvider);
      expect(state.phase, ShorebirdUpdatePhase.readyToRestart);
      expect(state.error, ShorebirdUpdateError.restartFailed);
    });

    test('platforms that cannot restart themselves never try', () async {
      restarter = _FakeRestarter(canRestartInApp: false);
      stubCheck(UpdateStatus.restartRequired);
      final c = container();
      final service = c.read(shorebirdUpdateServiceProvider.notifier);
      await service.checkForUpdate();

      expect(await service.restartToApply(), isFalse);
      expect(restarter.restarts, 0);
      expect(c.read(shorebirdUpdateServiceProvider).phase, ShorebirdUpdatePhase.readyToRestart);
    });
  });

  group('AppUpdateBanner', () {
    Future<ProviderContainer> pumpBanner(WidgetTester tester) async {
      final container = ProviderContainer.test(overrides: overrides());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: Column(children: [AppUpdateBanner(), Text('Home')])),
          ),
        ),
      );
      return container;
    }

    Finder banner() => find.byKey(const ValueKey('app-update-banner'));

    testWidgets('takes no space without an update', (tester) async {
      stubCheck(UpdateStatus.upToDate);
      final c = await pumpBanner(tester);
      await c.read(shorebirdUpdateServiceProvider.notifier).checkForUpdate();
      await tester.pump();

      expect(banner(), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('stays hidden while downloading, then offers Restart', (tester) async {
      stubCheck(UpdateStatus.outdated);
      final download = Completer<void>();
      when(() => updater.update(track: any(named: 'track'))).thenAnswer((_) => download.future);
      final c = await pumpBanner(tester);
      final check = c.read(shorebirdUpdateServiceProvider.notifier).checkForUpdate();
      await tester.pump();

      expect(c.read(shorebirdUpdateServiceProvider).phase, ShorebirdUpdatePhase.downloading);
      expect(banner(), findsNothing);

      when(() => updater.readNextPatch()).thenAnswer((_) async => const Patch(number: 1));
      download.complete();
      await tester.runAsync(() => check);
      await tester.pump();
      await tester.pump(_expand);

      expect(banner(), findsOneWidget);
      expect(find.text('Update ready'), findsOneWidget);
      expect(find.textContaining('Restart Myglo'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Restart'));
      await tester.pump();

      expect(restarter.restarts, 1);
      expect(find.byKey(const ValueKey('app-update-progress')), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull, reason: 'no second tap while restarting');
    });

    testWidgets('on iOS, Restart explains how to reopen the app', (tester) async {
      restarter = _FakeRestarter(canRestartInApp: false);
      stubCheck(UpdateStatus.restartRequired);
      final c = await pumpBanner(tester);
      await c.read(shorebirdUpdateServiceProvider.notifier).checkForUpdate();
      await tester.pump();
      await tester.pump(_expand);

      expect(find.textContaining('Close Myglo and open it again'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Restart'));
      await tester.pumpAndSettle();

      expect(find.text('Finish updating'), findsOneWidget);
      expect(restarter.restarts, 0);
    });

    testWidgets('a failed download stays hidden', (tester) async {
      stubCheck(UpdateStatus.outdated);
      when(() => updater.update(track: any(named: 'track'))).thenThrow(
        const UpdateException(message: 'network', reason: UpdateFailureReason.downloadFailed),
      );
      final c = await pumpBanner(tester);
      await c.read(shorebirdUpdateServiceProvider.notifier).checkForUpdate();
      await tester.pump();
      await tester.pump(_expand);

      expect(c.read(shorebirdUpdateServiceProvider).error, ShorebirdUpdateError.downloadFailed);
      expect(banner(), findsNothing);
    });
  });
}
