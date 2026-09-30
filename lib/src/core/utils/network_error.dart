import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Returns `true` when [error] indicates the request never reached (or never
/// returned from) the server, as opposed to the server rejecting it.
///
/// Used to decide whether a failed query is worth retrying automatically once
/// connectivity is restored.
bool isConnectivityError(Object error) {
  if (error is SocketException ||
      error is TlsException ||
      error is TimeoutException ||
      error is AuthRetryableFetchException) {
    return true;
  }

  // `package:http` ClientException wraps the underlying socket failure and is
  // not exported by supabase_flutter, so it is matched by its rendered form.
  final text = error.toString();
  return text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection reset') ||
      text.contains('Connection closed') ||
      text.contains('Network is unreachable');
}
