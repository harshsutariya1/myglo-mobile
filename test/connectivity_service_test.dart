import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/services/connectivity_service.dart';
import 'package:myglo/src/core/utils/app_provider_observer.dart';
import 'package:myglo/src/core/utils/network_error.dart';

/// Advances fake time in 100ms steps so chained timers / futures all fire.
Future<void> _elapse(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

class NetHarness {
  NetHarness({bool initiallyReachable = true}) : reachable = initiallyReachable {
    container = ProviderContainer(
      observers: const [AppProviderObserver()],
      overrides: [
        networkNudgesProvider.overrideWithValue(nudges.stream),
        reachabilityProbeProvider.overrideWithValue(() async {
          probeCount++;
          return reachable;
        }),
      ],
    );
    container.listen(networkStatusProvider, (_, next) => history.add(next));
  }

  void dispose() {
    container.dispose();
    nudges.close();
  }

  final nudges = StreamController<void>.broadcast();
  late final ProviderContainer container;
  bool reachable;
  int probeCount = 0;
  final history = <NetworkStatus>[];

  NetworkStatus get status => container.read(networkStatusProvider);
  NetworkStatusNotifier get notifier =>
      container.read(networkStatusProvider.notifier);
}

/// Runs [body] with a harness and disposes it inside the test body, so the
/// notifier's timers are cancelled before Flutter's pending-timer check.
void harnessTest(String name, Future<void> Function(WidgetTester, NetHarness) body) {
  testWidgets(name, (tester) async {
    final h = NetHarness();
    try {
      await body(tester, h);
    } finally {
      h.dispose();
    }
  });
}

void main() {
  group('NetworkStatusNotifier', () {
    harnessTest('starts online without popping the offline state', (tester, h) async {

      await _elapse(tester, const Duration(seconds: 1));

      expect(h.status, NetworkStatus.online);
      expect(h.history, isEmpty);
    });

    harnessTest('a single dropped probe does not go offline (flapping)', (tester, h) async {
      await _elapse(tester, const Duration(seconds: 1));

      // Link drops just before the 10s probe and is back for the re-check.
      await _elapse(tester, const Duration(milliseconds: 9500));
      h.reachable = false;
      await _elapse(tester, const Duration(milliseconds: 800));
      h.reachable = true;
      await _elapse(tester, const Duration(seconds: 15));

      expect(h.status, NetworkStatus.online);
      expect(h.history, isEmpty, reason: 'popup must never have mounted');
    });

    harnessTest('sustained failure goes offline after consecutive failed probes', (tester, h) async {
      await _elapse(tester, const Duration(seconds: 1));

      h.reachable = false;
      await _elapse(tester, const Duration(seconds: 13));

      expect(h.status, NetworkStatus.offline);
      expect(h.history, [NetworkStatus.offline]);
    });

    harnessTest('recovers online after consecutive good probes', (tester, h) async {
      await _elapse(tester, const Duration(seconds: 1));
      h.reachable = false;
      await _elapse(tester, const Duration(seconds: 13));
      expect(h.status, NetworkStatus.offline);

      h.reachable = true;
      await _elapse(tester, const Duration(seconds: 8));

      expect(h.status, NetworkStatus.online);
      expect(h.history, [NetworkStatus.offline, NetworkStatus.online]);
    });

    harnessTest('a committed state is held so the popup cannot flash', (tester, h) async {
      await _elapse(tester, const Duration(seconds: 1));
      h.reachable = false;
      await _elapse(tester, const Duration(seconds: 11));
      expect(h.status, NetworkStatus.offline);

      // Connection returns immediately after the popup appears; the hold window
      // (2s) must keep it up rather than flipping straight back.
      h.reachable = true;
      await _elapse(tester, const Duration(milliseconds: 1500));
      expect(h.status, NetworkStatus.offline);
    });

    harnessTest('manual recheck restores online immediately when reachable', (tester, h) async {
      await _elapse(tester, const Duration(seconds: 1));
      h.reachable = false;
      await _elapse(tester, const Duration(seconds: 13));
      expect(h.status, NetworkStatus.offline);

      expect(await h.notifier.recheck(userInitiated: true), isFalse);
      expect(h.status, NetworkStatus.offline);

      h.reachable = true;
      expect(await h.notifier.recheck(userInitiated: true), isTrue);
      expect(h.status, NetworkStatus.online);
    });

    harnessTest('automatic recheck keeps the debounce (no instant flip online)', (tester, h) async {
      await _elapse(tester, const Duration(seconds: 1));
      h.reachable = false;
      await _elapse(tester, const Duration(seconds: 13));
      expect(h.status, NetworkStatus.offline);

      h.reachable = true;
      await h.notifier.recheck(); // e.g. app resumed
      expect(h.status, NetworkStatus.offline, reason: 'one good probe is not enough');
      await _elapse(tester, const Duration(milliseconds: 1500)); // confirming probe
      expect(h.status, NetworkStatus.online);
    });

    harnessTest('link-change / failed-request nudges probe promptly, once per burst', (tester, h) async {
      await _elapse(tester, const Duration(seconds: 1));
      final before = h.probeCount;

      for (var i = 0; i < 10; i++) {
        h.nudges.add(null);
      }
      await _elapse(tester, const Duration(seconds: 1));

      expect(h.probeCount - before, 1);
    });

    harnessTest('a burst of failed queries from one blip does not go offline', (tester, h) async {
      await _elapse(tester, const Duration(seconds: 1));
      h.reachable = false;
      for (var i = 0; i < 6; i++) {
        h.notifier.onQueryFailed(FutureProvider<int>((ref) => 0));
      }
      await _elapse(tester, const Duration(milliseconds: 600));
      h.reachable = true; // blip over before the confirming probe
      await _elapse(tester, const Duration(seconds: 5));

      expect(h.status, NetworkStatus.online);
      expect(h.history, isEmpty);
    });

    harnessTest('concurrent rechecks share one in-flight probe', (tester, h) async {
      await _elapse(tester, const Duration(seconds: 1));
      final before = h.probeCount;

      await Future.wait([h.notifier.recheck(), h.notifier.recheck(), h.notifier.recheck()]);

      expect(h.probeCount - before, 1);
    });

    harnessTest('failed queries are re-run on reconnect, once', (tester, h) async {

      var builds = 0;
      // Riverpod 3 retries failed providers on its own with backoff; disabled
      // here so only the reconnect-driven retry is under test.
      final failingQuery = FutureProvider<int>((ref) async {
        builds++;
        if (!h.reachable) throw const SocketException('Failed host lookup');
        return builds;
      }, retry: (_, _) => null);
      await _elapse(tester, const Duration(seconds: 1));

      h.reachable = false;
      final sub = h.container.listen(failingQuery, (_, _) {});
      addTearDown(sub.close);
      await _elapse(tester, const Duration(seconds: 15)); // fails, goes offline
      expect(h.status, NetworkStatus.offline);
      expect(builds, 1, reason: 'no retry while still offline');

      h.reachable = true;
      await _elapse(tester, const Duration(seconds: 8));

      expect(h.status, NetworkStatus.online);
      expect(builds, 2, reason: 'retried exactly once after reconnect');
      expect(h.container.read(failingQuery).value, 2);
    });

    harnessTest('non-connectivity failures are not retried', (tester, h) async {

      var builds = 0;
      final failingQuery = FutureProvider<int>((ref) async {
        builds++;
        throw StateError('RLS denied');
      }, retry: (_, _) => null);
      await _elapse(tester, const Duration(seconds: 1));
      final sub = h.container.listen(failingQuery, (_, _) {});
      addTearDown(sub.close);

      h.reachable = false;
      await _elapse(tester, const Duration(seconds: 13));
      h.reachable = true;
      await _elapse(tester, const Duration(seconds: 8));

      expect(builds, 1);
    });
  });

  group('isConnectivityError', () {
    test('recognises transport failures', () {
      expect(isConnectivityError(const SocketException('x')), isTrue);
      expect(isConnectivityError(TimeoutException('x')), isTrue);
      expect(isConnectivityError(const HandshakeException('x')), isTrue);
      expect(
        isConnectivityError(Exception('ClientException with SocketException: Failed host lookup')),
        isTrue,
      );
    });

    test('ignores server-side / logic errors', () {
      expect(isConnectivityError(StateError('boom')), isFalse);
      expect(isConnectivityError(Exception('duplicate key value')), isFalse);
    });
  });
}
