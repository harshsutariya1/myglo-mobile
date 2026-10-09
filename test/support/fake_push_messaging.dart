import 'dart:async';

import 'package:myglo/src/features/shared/notifications/push/push_messaging.dart';

/// In-memory [PushMessaging] for tests: no Firebase, scripted permission.
class FakePushMessaging implements PushMessaging {
  FakePushMessaging({
    this.isSupported = true,
    this.currentPermission = PushPermission.canAsk,
    this.answer = PushPermission.granted,
    this.currentToken = 'fake-fcm-token-0123456789abcdefghijklmnopqrstuvwxyz',
  });

  @override
  final bool isSupported;
  PushPermission currentPermission;

  /// What the system prompt answers when [requestPermission] is called.
  PushPermission answer;
  String? currentToken;
  int permissionRequests = 0;
  int tokenDeletions = 0;
  PushMessage? launchMessage;

  final StreamController<String> refreshes = StreamController<String>.broadcast();
  final StreamController<PushMessage> opened = StreamController<PushMessage>.broadcast();
  final StreamController<PushMessage> foreground = StreamController<PushMessage>.broadcast();

  @override
  Future<PushPermission> permission() async => currentPermission;

  @override
  Future<PushPermission> requestPermission() async {
    permissionRequests++;
    currentPermission = answer;
    return currentPermission;
  }

  @override
  Future<String?> token() async => currentToken;

  @override
  Stream<String> get tokenRefreshes => refreshes.stream;

  @override
  Future<void> deleteToken() async {
    tokenDeletions++;
    currentToken = null;
  }

  @override
  Future<PushMessage?> initialMessage() async => launchMessage;

  @override
  Stream<PushMessage> get openedMessages => opened.stream;

  @override
  Stream<PushMessage> get foregroundMessages => foreground.stream;
}
