import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_logger.dart';

/// A Riverpod [ProviderObserver] that logs provider state changes,
/// additions, errors, and disposals cleanly in the debug console.
base class AppProviderObserver extends ProviderObserver {
  const AppProviderObserver();

  String _formatValue(Object? value) {
    if (value == null) return 'null';
    if (value is AsyncValue) {
      return value.when(
        data: (d) => 'AsyncData(${_truncate(d.toString(), 60)})',
        error: (e, _) => 'AsyncError($e)',
        loading: () => 'AsyncLoading',
      );
    }
    return _truncate(value.toString(), 60);
  }

  String _truncate(String str, int maxLen) {
    if (str.length <= maxLen) return str;
    return '${str.substring(0, maxLen)}...';
  }

  String _providerName(ProviderObserverContext context) {
    return context.provider.name ?? context.provider.runtimeType.toString();
  }

  @override
  void didAddProvider(
    ProviderObserverContext context,
    Object? value,
  ) {
    if (kDebugMode) {
      AppLogger.d('➕ Init: ${_formatValue(value)}', tag: _providerName(context));
    }
  }

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (kDebugMode) {
      AppLogger.state(
        _providerName(context),
        '${_formatValue(previousValue)} ➔ ${_formatValue(newValue)}',
      );
    }
  }

  @override
  void didDisposeProvider(
    ProviderObserverContext context,
  ) {
    if (kDebugMode) {
      AppLogger.d('🗑️ Disposed', tag: _providerName(context));
    }
  }

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    AppLogger.e(
      'Provider threw an exception',
      tag: _providerName(context),
      error: error,
      stackTrace: stackTrace,
    );
  }
}
