import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_logger.dart';

/// Hands a phone number or email address to the device's phone, messages or
/// mail app. Each method returns whether an app opened; false means there's
/// nothing to handle it (e.g. a tablet without a phone app) and the caller
/// should offer another way, such as copying.
abstract interface class ContactLauncher {
  Future<bool> call(String phone);

  Future<bool> message(String phone);

  Future<bool> email(String address);
}

final contactLauncherProvider = Provider<ContactLauncher>((ref) => const UrlContactLauncher());

class UrlContactLauncher implements ContactLauncher {
  const UrlContactLauncher();

  static const _tag = 'ContactLauncher';

  @override
  Future<bool> call(String phone) => _launch(phoneUri('tel', phone));

  @override
  Future<bool> message(String phone) => _launch(phoneUri('sms', phone));

  @override
  Future<bool> email(String address) => _launch(Uri(scheme: 'mailto', path: address.trim()));

  /// `tel:0412345678` from `0412 345 678`: only digits, plus a leading `+`
  /// for international numbers. Null when nothing dialable is left.
  static Uri? phoneUri(String scheme, String phone) {
    final trimmed = phone.trim();
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    return Uri(scheme: scheme, path: trimmed.startsWith('+') ? '+$digits' : digits);
  }

  Future<bool> _launch(Uri? uri) async {
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e, st) {
      AppLogger.e('Opening a ${uri.scheme} link failed', tag: _tag, error: e, stackTrace: st);
      return false;
    }
  }
}
