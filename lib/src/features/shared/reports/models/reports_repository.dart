import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/app_logger.dart';
import '../../authentication/models/auth_repository.dart';
import 'report.dart';
import 'report_failure.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(supabaseClientProvider));
});

/// Reports to Myglo's team. Sent through `submit_report`, which checks the
/// reporter can see what they report, limits how many they send, and holds a
/// reported booking's payout until an admin looks at it.
class ReportsRepository {
  ReportsRepository(this._client);

  final SupabaseClient _client;

  /// Sends a report and returns its id. Reporting the same thing again while
  /// the first report is open returns that report.
  Future<String> submit({
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String? details,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final id =
          await _client.rpc(
                'submit_report',
                params: {
                  'p_target_type': target.key,
                  'p_target_id': targetId,
                  'p_reason': reason.key,
                  'p_details': details?.trim().isEmpty ?? true ? null : details!.trim(),
                },
              )
              as String;
      sw.stop();
      AppLogger.api('rpc.submit_report', endpoint: target.key, duration: sw.elapsed);
      return id;
    } catch (e, st) {
      throwReportError(e, st, action: 'Report ${target.key}');
    }
  }
}
