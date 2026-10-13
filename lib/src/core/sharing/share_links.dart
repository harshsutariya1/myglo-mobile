import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../platform/system_bridge.dart';
import '../utils/app_logger.dart';
import '../widgets/snackbar_utils.dart';

/// Public links to things in the app. They open the app when it's installed
/// (Android App Links / iOS Universal Links) and the website otherwise; the
/// router handles the same paths (see docs/share_links.md).
abstract final class ShareLinks {
  /// Path prefix of a shared post: `/p/<id>`.
  static const String postPrefix = '/p/';

  /// Path prefix of a shared provider profile: `/provider/<id>`.
  static const String providerPrefix = '/provider/';

  static final RegExp _id = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  static Uri post(String postId) => Uri.https(AppConfig.shareLinkHost, '$postPrefix$postId');

  static Uri provider(String providerId) => Uri.https(AppConfig.shareLinkHost, '$providerPrefix$providerId');

  /// Whether [path] is exactly a shared post or provider link, so it's safe
  /// to remember and open after sign-in.
  static bool isShareable(String path) {
    for (final prefix in [postPrefix, providerPrefix]) {
      if (path.startsWith(prefix) && _id.hasMatch(path.substring(prefix.length))) return true;
    }
    return false;
  }
}

/// Opens the system share sheet for [url], with [text] before it. Shows a
/// snackbar if sharing isn't available. [context] should be the tapped
/// widget's, so the sheet points at it on iPad.
Future<void> shareLink(
  BuildContext context,
  WidgetRef ref, {
  required String text,
  required Uri url,
  String? subject,
}) async {
  final box = context.findRenderObject();
  final origin = box is RenderBox && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
  final opened = await ref.read(systemBridgeProvider).share(text: text, url: url, subject: subject, origin: origin);
  if (opened) return;
  AppLogger.w('Share sheet did not open for $url', tag: 'Share');
  if (context.mounted) context.showAppSnackBar("Sharing isn't available on this device.", isError: true);
}
