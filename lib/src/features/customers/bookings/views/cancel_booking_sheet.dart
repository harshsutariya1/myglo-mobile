import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/bookings/controllers/booking_controllers.dart';
import '../../../shared/bookings/models/booking.dart';
import '../../../shared/bookings/models/booking_enums.dart';
import '../../../shared/bookings/models/booking_failure.dart';

/// Asks the client to confirm cancelling [booking] and cancels it.
///
/// Inside the provider's cancellation window the sheet spells out the
/// consequences (late cancellation, any fee owed) and the client has to tick
/// that they understand before the button enables. The server enforces the
/// same rule, so a sheet opened just before the window closed is caught too.
/// Returns the cancelled booking, or null if the client kept it.
Future<Booking?> showCancelBookingSheet(BuildContext context, {required Booking booking}) {
  return showModalBottomSheet<Booking>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _CancelBookingSheet(booking: booking),
  );
}

class _CancelBookingSheet extends ConsumerStatefulWidget {
  const _CancelBookingSheet({required this.booking});

  final Booking booking;

  @override
  ConsumerState<_CancelBookingSheet> createState() => _CancelBookingSheetState();
}

class _CancelBookingSheetState extends ConsumerState<_CancelBookingSheet> {
  final _reason = TextEditingController();
  late bool _late = widget.booking.isLateToCancel(DateTime.now());
  bool _acknowledged = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final cancelled = await ref.read(bookingActionsProvider).cancel(
            widget.booking.id,
            reason: _reason.text.trim(),
            acceptLateCancellation: _late && _acknowledged,
          );
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(cancelled);
    } on BookingFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (failure.code == BookingFailureCode.lateCancellationUnconfirmed) {
          // The window closed while the sheet was open: show the terms.
          _late = true;
          _acknowledged = false;
          _error = 'The free cancellation window has just closed. Please review the terms below.';
        } else {
          _error = failure.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final booking = widget.booking;
    final fee = booking.lateFeeCents;
    final pending = booking.status == BookingStatus.pending;
    final canSubmit = !_busy && (!_late || _acknowledged);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              pending ? 'Withdraw request?' : 'Cancel booking?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scheme.onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              '${booking.servicesSummary} with ${booking.providerName} · ${Formatters.dateTimeShort(booking.startsAtLocal)}',
              style: TextStyle(fontSize: 14, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 18),
            if (_late)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.destructive.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppTheme.destructive, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This is a late cancellation',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Free cancellation ended ${Formatters.dateTimeShort(booking.startsAtLocal.subtract(Duration(hours: booking.cancellationWindowHours)))} '
                      '(${booking.cancellationWindowHours} hours before the appointment). '
                      '${fee > 0 ? 'A late-cancellation fee of ${Formatters.audCents(fee)} (${booking.cancellationFeePercent}%) '
                          'will be owed to ${booking.providerName}.' : '${booking.providerName} will see it marked as a late cancellation.'}',
                      style: TextStyle(fontSize: 13.5, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.75)),
                    ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      value: _acknowledged,
                      onChanged: _busy ? null : (value) => setState(() => _acknowledged = value ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppTheme.destructive,
                      dense: true,
                      title: Text(
                        fee > 0 ? 'I understand the fee and want to cancel' : 'I understand and want to cancel',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onSurface),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Free to cancel. Nothing is owed.',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              enabled: !_busy,
              maxLength: 300,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Let ${booking.providerName} know why',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.destructive)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: canSubmit ? _cancel : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.destructive,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                ),
                child: _busy
                    ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text(pending ? 'Withdraw request' : 'Cancel booking'),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurface,
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: const Text('Keep booking'),
            ),
          ],
        ),
      ),
    );
  }
}
