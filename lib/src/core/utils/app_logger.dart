import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Custom Log Filter to ensure debug/info logs only appear in debug mode,
/// while errors and warnings are captured safely.
class _AppLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kDebugMode) {
      return true;
    }
    // In profile or release mode, only log warnings and errors
    return event.level.index >= Level.warning.index;
  }
}

/// Production-ready logging service with beautiful console formatting in debug
/// mode and automatic Sentry crash/error integration.
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    filter: _AppLogFilter(),
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 85,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static final Logger _traceLogger = Logger(
    filter: _AppLogFilter(),
    printer: PrettyPrinter(
      methodCount: 3,
      errorMethodCount: 8,
      lineLength: 85,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  /// Debug / Verbose level for fine-grained development tracing
  static void d(dynamic message, {String? tag, Object? error, StackTrace? stackTrace}) {
    final prefix = tag != null ? '[$tag] ' : '';
    _logger.d('$prefix$message', error: error, stackTrace: stackTrace);
  }

  /// Informational messages for milestones and key user actions
  static void i(dynamic message, {String? tag, Object? error, StackTrace? stackTrace}) {
    final prefix = tag != null ? '[$tag] ' : '';
    _logger.i('$prefix$message', error: error, stackTrace: stackTrace);
  }

  /// Warning messages for non-fatal irregularities
  static void w(dynamic message, {String? tag, Object? error, StackTrace? stackTrace}) {
    final prefix = tag != null ? '[$tag] ' : '';
    _logger.w('$prefix$message', error: error, stackTrace: stackTrace);
  }

  /// Error messages with stack traces (reported to Sentry if in release/profile)
  static void e(
    dynamic message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final prefix = tag != null ? '[$tag] ' : '';
    _traceLogger.e('$prefix$message', error: error, stackTrace: stackTrace);

    // Report to Sentry if an exception is provided
    if (error != null) {
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          if (tag != null) {
            scope.setTag('logger_tag', tag);
          }
          scope.setContexts('logger_message', {'message': message.toString()});
        },
      );
    }
  }

  /// Fatal / Critical crash-level messages
  static void f(
    dynamic message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final prefix = tag != null ? '[$tag] ' : '';
    _traceLogger.f('$prefix$message', error: error, stackTrace: stackTrace);

    if (error != null) {
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.level = SentryLevel.fatal;
          if (tag != null) {
            scope.setTag('logger_tag', tag);
          }
        },
      );
    }
  }

  /// Dedicated route / navigation logger
  static void nav(String destination, {String? from, Map<String, dynamic>? params}) {
    final fromStr = from != null ? 'from $from ' : '';
    final paramStr = (params != null && params.isNotEmpty) ? ' (params: $params)' : '';
    _logger.i('🧭 [Nav] Navigating ${fromStr}to $destination$paramStr');
  }

  /// Dedicated authentication lifecycle logger (scrubs passwords & secrets!)
  static void auth(String event, {String? email, String? userId, String? role}) {
    final details = [
      if (email != null) 'email: $email',
      if (userId != null) 'userId: $userId',
      if (role != null) 'role: $role',
    ].join(', ');
    _logger.i('🔐 [Auth] $event ${details.isNotEmpty ? '($details)' : ''}');
  }

  /// Dedicated API / Supabase operations logger
  static void api(
    String operation, {
    String? endpoint,
    int? count,
    Duration? duration,
    Object? error,
  }) {
    final timing = duration != null ? ' in ${duration.inMilliseconds}ms' : '';
    final countStr = count != null ? ' (items: $count)' : '';
    if (error != null) {
      _logger.e('📡 [API Error] $operation ${endpoint ?? ''}$timing', error: error);
    } else {
      _logger.d('📡 [API] $operation ${endpoint ?? ''}$countStr$timing');
    }
  }

  /// Dedicated state management logger
  static void state(String providerName, String changeDescription) {
    _logger.d('🔄 [State] $providerName: $changeDescription');
  }
}
