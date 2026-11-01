import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/shared/authentication/models/auth_repository.dart';
import '../utils/app_logger.dart';

/// Platform settings the app needs to know up front, set by Myglo's admins
/// on the server (`get_app_config`). The server enforces every one of them;
/// the app only uses them to explain things before the client hits a limit.
class RemoteAppConfig {
  const RemoteAppConfig({
    this.cardMaxAdvanceDays = defaultCardMaxAdvanceDays,
    this.checkoutHoldMinutes = 15,
    this.reportWindowHours = defaultReportWindowHours,
  });

  factory RemoteAppConfig.fromJson(Map<String, dynamic> json) => RemoteAppConfig(
    cardMaxAdvanceDays: (json['card_max_advance_days'] as num?)?.toInt() ?? defaultCardMaxAdvanceDays,
    checkoutHoldMinutes: (json['checkout_hold_minutes'] as num?)?.toInt() ?? 15,
    reportWindowHours: (json['report_window_hours'] as num?)?.toInt() ?? defaultReportWindowHours,
  );

  /// The server's default (Stripe holds card funds for at most 90 days).
  static const int defaultCardMaxAdvanceDays = 60;

  /// Appointments further ahead than this can't be paid in the app.
  final int cardMaxAdvanceDays;

  /// How long an unpaid card checkout holds the time.
  final int checkoutHoldMinutes;

  /// The server's default report window.
  static const int defaultReportWindowHours = 24;

  /// How long after an appointment ends the client can report a problem.
  final int reportWindowHours;
}

/// The admin-set platform settings, loaded once per session. Falls back to
/// the server's defaults if they can't be loaded, since the server checks
/// them again anyway.
final remoteAppConfigProvider = FutureProvider<RemoteAppConfig>((ref) async {
  try {
    final row = await ref.watch(supabaseClientProvider).rpc('get_app_config');
    return row is Map ? RemoteAppConfig.fromJson(Map<String, dynamic>.from(row)) : const RemoteAppConfig();
  } catch (e) {
    AppLogger.w('App config unavailable; using defaults', tag: 'AppConfig', error: e);
    return const RemoteAppConfig();
  }
});
