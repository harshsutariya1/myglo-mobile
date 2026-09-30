import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../features/shared/authentication/models/auth_repository.dart';
import '../network/connectivity_aware_client.dart';
import '../utils/app_logger.dart';

enum NetworkStatus { online, offline }

/// Resolves to `true` when the backend is reachable, `false` when it is not,
/// or `null` when the check itself failed for an unexpected reason.
typedef ReachabilityProbe = Future<bool?> Function();

/// Tuning knobs for [NetworkStatusNotifier].
///
/// A state change is only committed after several consecutive probes agree and
/// is then held for [holdDuration], so a flapping link cannot make the offline
/// popup flash or repeatedly mount/unmount.
class NetworkTimings {
  const NetworkTimings({
    this.onlineInterval = const Duration(seconds: 10),
    this.offlineInterval = const Duration(seconds: 3),
    this.verifyInterval = const Duration(seconds: 1),
    this.holdDuration = const Duration(seconds: 2),
    this.failuresToGoOffline = 2,
    this.successesToGoOnline = 2,
  });

  /// Probe cadence while online and healthy.
  final Duration onlineInterval;

  /// Probe cadence while offline.
  final Duration offlineInterval;

  /// Probe cadence while a state change is being confirmed.
  final Duration verifyInterval;

  /// Minimum time a committed state is kept before it may flip again.
  final Duration holdDuration;

  final int failuresToGoOffline;
  final int successesToGoOnline;
}

final networkTimingsProvider = Provider<NetworkTimings>(
  (ref) => const NetworkTimings(),
);

/// Opens a real TLS connection to [host]. Unlike a Wi-Fi/cellular link flag,
/// this only succeeds when DNS, TCP and the TLS handshake to the backend work,
/// and it fails behind captive portals.
Future<bool?> secureSocketProbe(
  String host, {
  int port = 443,
  Duration timeout = const Duration(seconds: 4),
}) async {
  try {
    final socket = await SecureSocket.connect(host, port, timeout: timeout);
    socket.destroy();
    return true;
  } on SocketException {
    return false;
  } on TlsException {
    return false;
  } on TimeoutException {
    return false;
  } catch (e, st) {
    AppLogger.e(
      'Unexpected error while probing $host',
      tag: 'Network',
      error: e,
      stackTrace: st,
    );
    return null;
  }
}

final reachabilityProbeProvider = Provider<ReachabilityProbe>((ref) {
  final host = Uri.parse(ref.watch(supabaseClientProvider).rest.url).host;
  return () => secureSocketProbe(host);
});

/// Events that suggest reachability may have changed: the OS reporting a link
/// change, or a request failing mid-flight. They only *trigger* a probe; they
/// are never trusted as the answer.
final networkNudgesProvider = Provider<Stream<void>>((ref) {
  final controller = StreamController<void>();
  final subscriptions = [
    Connectivity().onConnectivityChanged.listen((_) => controller.add(null)),
    requestConnectivityFailures.listen((_) => controller.add(null)),
  ];
  ref.onDispose(() {
    for (final sub in subscriptions) {
      sub.cancel();
    }
    controller.close();
  });
  return controller.stream;
});

final networkStatusProvider =
    NotifierProvider<NetworkStatusNotifier, NetworkStatus>(
      NetworkStatusNotifier.new,
    );

/// Tracks whether the Supabase backend is actually reachable.
///
/// Read-only queries that failed with a connectivity error are re-run when the
/// connection returns. Mutations are never replayed: they are only ever
/// re-submitted by the user, and the repositories send a client-generated id so
/// such a re-submission cannot create a duplicate row.
class NetworkStatusNotifier extends Notifier<NetworkStatus> {
  late final NetworkTimings _timings = ref.read(networkTimingsProvider);

  Timer? _probeTimer;
  Timer? _holdTimer;
  Timer? _nudgeTimer;
  Future<bool?>? _inFlight;
  int _failures = 0;
  int _successes = 0;
  bool _disposed = false;

  final Set<ProviderOrFamily> _failedQueries = {};

  @override
  NetworkStatus build() {
    ref.onDispose(() {
      _disposed = true;
      _probeTimer?.cancel();
      _holdTimer?.cancel();
      _nudgeTimer?.cancel();
    });
    final nudges = ref.watch(networkNudgesProvider).listen((_) => _nudge());
    ref.onDispose(nudges.cancel);
    _schedule(Duration.zero);
    return NetworkStatus.online;
  }

  /// Probes now. Automatic callers (app resume, failed requests, link changes)
  /// go through the normal debouncing. A [userInitiated] check (the Retry
  /// button) that finds the backend reachable restores the online state
  /// immediately, because the user explicitly asked.
  Future<bool> recheck({bool userInitiated = false}) async {
    _probeTimer?.cancel();
    final reachable = await _probe();
    if (_disposed) return reachable ?? state == NetworkStatus.online;

    if (userInitiated && reachable == true && state == NetworkStatus.offline) {
      _commit(NetworkStatus.online);
    }
    _schedule(_nextDelay());
    return reachable ?? state == NetworkStatus.online;
  }

  /// Called when a provider failed with a connectivity error: remembers it for
  /// retry and nudges the probe so the popup appears without waiting for the
  /// next scheduled check.
  void onQueryFailed(ProviderOrFamily provider) {
    if (_disposed) return;
    _failedQueries.add(provider);
    _nudge();
  }

  void onQueryDisposed(ProviderOrFamily provider) {
    _failedQueries.remove(provider);
  }

  /// Runs (or joins) a single probe and records its result exactly once, no
  /// matter how many callers were waiting on it.
  Future<bool?> _probe() => _inFlight ??= _runProbe();

  Future<bool?> _runProbe() async {
    try {
      final reachable = await ref.read(reachabilityProbeProvider)();
      if (!_disposed && reachable != null) {
        _count(reachable);
        _evaluate();
      }
      return reachable;
    } finally {
      _inFlight = null;
    }
  }

  /// Coalesces bursts of signals (e.g. ten providers failing together) into one
  /// probe.
  void _nudge() {
    if (_disposed) return;
    _nudgeTimer?.cancel();
    _nudgeTimer = Timer(const Duration(milliseconds: 300), () {
      if (!_disposed) unawaited(recheck());
    });
  }

  void _schedule(Duration delay) {
    _probeTimer?.cancel();
    if (_disposed) return;
    _probeTimer = Timer(delay, () async {
      await _probe();
      if (_disposed) return;
      _schedule(_nextDelay());
    });
  }

  Duration _nextDelay() {
    if (state == NetworkStatus.online) {
      return _failures > 0 ? _timings.verifyInterval : _timings.onlineInterval;
    }
    return _successes > 0 ? _timings.verifyInterval : _timings.offlineInterval;
  }

  void _count(bool reachable) {
    if (reachable) {
      _successes++;
      _failures = 0;
    } else {
      _failures++;
      _successes = 0;
    }
  }

  void _evaluate() {
    if (_holdTimer != null) return;
    if (state == NetworkStatus.online &&
        _failures >= _timings.failuresToGoOffline) {
      _commit(NetworkStatus.offline);
    } else if (state == NetworkStatus.offline &&
        _successes >= _timings.successesToGoOnline) {
      _commit(NetworkStatus.online);
    }
  }

  void _commit(NetworkStatus next) {
    _failures = 0;
    _successes = 0;
    state = next;

    _holdTimer?.cancel();
    _holdTimer = Timer(_timings.holdDuration, () {
      _holdTimer = null;
      if (!_disposed) _evaluate();
    });

    AppLogger.i('Network status changed to ${next.name}', tag: 'Network');
    Sentry.addBreadcrumb(
      Breadcrumb(
        category: 'network',
        message: 'Backend reachability: ${next.name}',
        level: SentryLevel.info,
      ),
    );

    if (next == NetworkStatus.online) _retryFailedQueries();
  }

  void _retryFailedQueries() {
    if (_failedQueries.isEmpty) return;
    AppLogger.i(
      'Reconnected: retrying ${_failedQueries.length} failed queries',
      tag: 'Network',
    );
    final pending = List.of(_failedQueries);
    _failedQueries.clear();
    for (final provider in pending) {
      ref.invalidate(provider);
    }
  }
}
