import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../models/report.dart';
import '../models/report_failure.dart';
import '../models/reports_repository.dart';

/// The most a reporter can write, matching `submit_report`.
const int reportDetailsMaxLength = 1000;

/// Asks why [targetId] is being reported and sends the report to Myglo's
/// team. [note] adds context under the title (e.g. that a booking's payout
/// is held). Thanks the reporter once it's sent; returns whether it was.
Future<bool> showReportSheet(
  BuildContext context, {
  required ReportTarget target,
  required String targetId,
  String? note,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => ReportSheet(target: target, targetId: targetId, note: note),
  );
  if (sent == true && context.mounted) {
    context.showAppSnackBar("Thanks for telling us. Myglo's team will look into it.");
  }
  return sent ?? false;
}

class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({super.key, required this.target, required this.targetId, this.note});

  final ReportTarget target;
  final String targetId;
  final String? note;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  final _details = TextEditingController();
  ReportReason? _reason;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  /// "Something else" needs a few words so the team knows what to look for.
  bool get _canSend => !_busy && _reason != null && (_reason != ReportReason.other || _details.text.trim().isNotEmpty);

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(reportsRepositoryProvider)
          .submit(target: widget.target, targetId: widget.targetId, reason: reason, details: _details.text);
      HapticFeedback.lightImpact();
      if (mounted) Navigator.of(context).pop(true);
    } on ReportFailure catch (failure) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = failure.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final isBooking = widget.target == ReportTarget.booking;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isBooking ? 'Report a problem' : 'Report ${widget.target.noun}',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scheme.onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              isBooking
                  ? "Tell Myglo's team what went wrong with this appointment."
                  : "Reports are private: we don't tell anyone who sent them.",
              style: TextStyle(fontSize: 14, height: 1.4, color: muted),
            ),
            if (widget.note case final note?) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.secondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(note, style: TextStyle(fontSize: 13.5, height: 1.4, color: scheme.onSurface)),
              ),
            ],
            const SizedBox(height: 10),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (value) {
                if (_busy) return;
                setState(() => _reason = value);
              },
              child: Column(
                children: [
                  for (final reason in widget.target.reasons)
                    RadioListTile<ReportReason>(
                      value: reason,
                      enabled: !_busy,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(reason.labelFor(widget.target), style: const TextStyle(fontSize: 15)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _details,
              enabled: !_busy,
              maxLength: reportDetailsMaxLength,
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _reason == ReportReason.other ? 'What happened?' : 'More details (optional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.destructive),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _canSend ? _send : null,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                ),
                child: _busy
                    ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : const Text('Send report'),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurface,
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
