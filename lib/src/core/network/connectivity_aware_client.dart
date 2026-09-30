import 'dart:async';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../utils/network_error.dart';

final _failures = StreamController<void>.broadcast();

/// Fires whenever a request made through [ConnectivityAwareHttpClient] fails
/// because the connection was lost or timed out. The network status notifier
/// uses it to probe immediately instead of waiting for its next poll.
Stream<void> get requestConnectivityFailures => _failures.stream;

/// The HTTP client handed to Supabase, so every auth, database, RPC and storage
/// call goes through one place that
///  * bounds how long a request may hang, and
///  * reports mid-flight connection failures to the connectivity layer.
///
/// It never retries: a request cut off in transit may or may not have reached
/// the server, and replaying it here could duplicate a write.
class ConnectivityAwareHttpClient extends http.BaseClient {
  ConnectivityAwareHttpClient({
    http.Client? inner,
    this.timeout = AppConfig.requestTimeout,
  }) : _inner = inner ?? http.Client();

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      return await _inner.send(request).timeout(timeout);
    } catch (error) {
      if (isConnectivityError(error)) _failures.add(null);
      rethrow;
    }
  }

  @override
  void close() => _inner.close();
}
