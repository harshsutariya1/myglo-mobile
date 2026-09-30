import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:myglo/src/core/network/connectivity_aware_client.dart';

void main() {
  test('passes successful responses through untouched', () async {
    final client = ConnectivityAwareHttpClient(
      inner: MockClient((_) async => http.Response('ok', 200)),
    );

    final response = await client.get(Uri.parse('https://example.test/x'));

    expect(response.statusCode, 200);
    expect(response.body, 'ok');
  });

  test('reports a dropped connection once and never retries', () async {
    var attempts = 0;
    final client = ConnectivityAwareHttpClient(
      inner: MockClient((_) async {
        attempts++;
        throw const SocketException('Connection reset by peer');
      }),
    );
    var signals = 0;
    final sub = requestConnectivityFailures.listen((_) => signals++);
    addTearDown(sub.cancel);

    await expectLater(
      client.post(Uri.parse('https://example.test/rest/v1/posts'), body: '{}'),
      throwsA(isA<SocketException>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(attempts, 1, reason: 'a possibly-delivered write must not be replayed');
    expect(signals, 1);
  });

  test('a request that hangs past the timeout fails and is reported', () async {
    final client = ConnectivityAwareHttpClient(
      timeout: const Duration(milliseconds: 50),
      inner: MockClient((_) => Completer<http.Response>().future),
    );
    var signals = 0;
    final sub = requestConnectivityFailures.listen((_) => signals++);
    addTearDown(sub.cancel);

    await expectLater(
      client.get(Uri.parse('https://example.test/x')),
      throwsA(isA<TimeoutException>()),
    );
    await Future<void>.delayed(Duration.zero);

    expect(signals, 1);
  });

  test('server-side errors are not treated as connectivity failures', () async {
    final client = ConnectivityAwareHttpClient(
      inner: MockClient((_) async => http.Response('{"code":"23505"}', 409)),
    );
    var signals = 0;
    final sub = requestConnectivityFailures.listen((_) => signals++);
    addTearDown(sub.cancel);

    final response = await client.get(Uri.parse('https://example.test/x'));
    await Future<void>.delayed(Duration.zero);

    expect(response.statusCode, 409);
    expect(signals, 0);
  });
}
