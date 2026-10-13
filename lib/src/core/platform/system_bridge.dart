import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_logger.dart';

/// Small platform queries and shortcuts the app needs without a package
/// (channel `app.myglo/system`, see `MainActivity.kt` and `AppDelegate.swift`).
abstract interface class SystemBridge {
  /// Whether a Google Maps key was built into the app. Without one a map
  /// would render blank (Android) or crash (iOS), so callers show a
  /// placeholder instead.
  Future<bool> mapsAvailable();

  /// Whether the system currently lets this app post notifications.
  Future<bool> notificationsEnabled();

  /// Opens this app's notification settings. Returns whether anything opened.
  Future<bool> openNotificationSettings();

  /// Opens the system share sheet with [text] followed by [url]. [subject] is
  /// used by apps that take one (e.g. email, on Android). [origin] is where
  /// the sheet points from on iPad (the tapped button, in global
  /// coordinates). Returns whether the sheet opened.
  Future<bool> share({required String text, required Uri url, String? subject, Rect? origin});

  /// Opens [url] (http or https) outside the app. [appUrl] (iOS) or
  /// [appPackage] (Android) name the app to try first, e.g. a maps app; if
  /// it isn't installed, [url] opens in whichever app handles it, usually
  /// the browser. Returns whether anything opened.
  Future<bool> openUrl(Uri url, {Uri? appUrl, String? appPackage});
}

final systemBridgeProvider = Provider<SystemBridge>((ref) => const MethodChannelSystemBridge());

/// Resolved once per app run: the key can't change while the app is running.
final mapsAvailableProvider = FutureProvider<bool>((ref) => ref.watch(systemBridgeProvider).mapsAvailable());

class MethodChannelSystemBridge implements SystemBridge {
  const MethodChannelSystemBridge();

  static const MethodChannel _channel = MethodChannel('app.myglo/system');

  @override
  Future<bool> mapsAvailable() => _invoke('mapsAvailable', fallback: false);

  @override
  Future<bool> notificationsEnabled() => _invoke('notificationsEnabled', fallback: false);

  @override
  Future<bool> openNotificationSettings() => _invoke('openNotificationSettings', fallback: false);

  @override
  Future<bool> share({required String text, required Uri url, String? subject, Rect? origin}) => _invoke(
        'share',
        fallback: false,
        arguments: {
          'text': text,
          'url': url.toString(),
          'subject': ?subject,
          if (origin != null) ...{
            'originX': origin.left,
            'originY': origin.top,
            'originWidth': origin.width,
            'originHeight': origin.height,
          },
        },
      );

  @override
  Future<bool> openUrl(Uri url, {Uri? appUrl, String? appPackage}) => _invoke(
        'openUrl',
        fallback: false,
        arguments: {
          'url': url.toString(),
          'appUrl': ?appUrl?.toString(),
          'appPackage': ?appPackage,
        },
      );

  Future<bool> _invoke(String method, {required bool fallback, Map<String, Object>? arguments}) async {
    try {
      return await _channel.invokeMethod<bool>(method, arguments) ?? fallback;
    } on MissingPluginException {
      // Platforms without the native side (tests, desktop).
      return fallback;
    } catch (e, st) {
      AppLogger.e('System bridge call "$method" failed', tag: 'SystemBridge', error: e, stackTrace: st);
      return fallback;
    }
  }
}
