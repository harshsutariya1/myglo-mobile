import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../shared/bookings/controllers/booking_controllers.dart';
import '../../../../shared/bookings/models/booking.dart';
import '../../../../shared/bookings/models/booking_enums.dart';
import '../../../../shared/bookings/models/booking_failure.dart';

/// What a provider is about to do to a booking from a confirmation sheet.
enum ProviderBookingAction { decline, cancel, complete, noShow }

/// Confirms [action] on [booking] and performs it. Returns the updated
/// booking, or null when the provider backed out.
Future<Booking?> showProviderBookingActionSheet(
  BuildContext context, {
  required Booking booking,
  required ProviderBookingAction action,
}) {
  return showModalBottomSheet<Booking>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _ProviderBookingActionSheet(booking: booking, action: action),
  );
}

class _ProviderBookingActionSheet extends ConsumerStatefulWidget {
  const _ProviderBookingActionSheet({required this.booking, required this.action});

  final Booking booking;
  final ProviderBookingAction action;

  @override
  ConsumerState<_ProviderBookingActionSheet> createState() => _ProviderBookingActionSheetState();
}

class _ProviderBookingActionSheetState extends ConsumerState<_ProviderBookingActionSheet> {
  static const _maxReasonLength = 300;

  final _reason = TextEditingController();
  bool _cashReceived = true;
  bool _busy = false;
  String? _error;

  Booking get _booking => widget.booking;

  bool get _destructive => widget.action != ProviderBookingAction.complete;

  bool get _needsReason => widget.action == ProviderBookingAction.cancel;

  bool get _takesReason => widget.action == ProviderBookingAction.decline || _needsReason;

  @override
  void initState() {
    super.initState();
    _reason.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final actions = ref.read(bookingActionsProvider);
    final reason = _reason.text.trim();
    try {
      final updated = await switch (widget.action) {
        ProviderBookingAction.decline => actions.decline(_booking.id, reason: reason.isEmpty ? null : reason),
        ProviderBookingAction.cancel => actions.cancel(_booking.id, reason: reason),
        ProviderBookingAction.complete => actions.complete(_booking.id, paymentReceived: _cashReceived),
        ProviderBookingAction.noShow => actions.markNoShow(_booking.id),
      };
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(updated);
    } on BookingFailure catch (failure) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = failure.message;
        });
      }
    }
  }

  ({String title, String body, String confirm}) get _copy {
    final client = _booking.clientName;
    final total = Formatters.audCents(_booking.totalCents);
    final fee = _booking.lateFeeCents;
    return switch (widget.action) {
      ProviderBookingAction.decline => (
          title: 'Decline request?',
          body: "$client will be told you can't take this booking, and the time opens up for others.",
          confirm: 'Decline request',
        ),
      ProviderBookingAction.cancel => (
          title: 'Cancel appointment?',
          body: '$client will be notified straight away and the time opens up for others. '
              'Nothing is owed by either of you.',
          confirm: 'Cancel appointment',
        ),
      ProviderBookingAction.complete => (
          title: 'Complete appointment',
          body: '${_booking.servicesSummary} · $total',
          confirm: 'Mark as completed',
        ),
      ProviderBookingAction.noShow => (
          title: "$client didn't show up?",
          body: fee > 0
              ? 'This closes the booking as a missed appointment. Under your policy, '
                  '${Formatters.audCents(fee)} (${_booking.lateFeePercent}%) is owed.'
              : 'This closes the booking as a missed appointment and lets $client know.'
                  '${_booking.paymentMethod.isCash ? ' Cash bookings carry no no-show fee.' : ''}',
          confirm: 'Mark as no-show',
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final copy = _copy;
    final cash = _booking.paymentMethod == PaymentMethod.cash;
    final canSubmit = !_busy && (!_needsReason || _reason.text.trim().isNotEmpty);
    final accent = _destructive ? AppTheme.destructive : scheme.onSurface;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(copy.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scheme.onSurface)),
            const SizedBox(height: 6),
            Text(
              '${_booking.servicesSummary} · ${Formatters.dateTimeShort(_booking.startsAtLocal)}',
              style: TextStyle(fontSize: 14, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            if (widget.action != ProviderBookingAction.complete)
              Text(
                copy.body,
                style: TextStyle(fontSize: 14.5, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.78)),
              ),
            if (widget.action == ProviderBookingAction.complete)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: CheckboxListTile(
                  value: _cashReceived,
                  onChanged: _busy || _booking.paymentStatus != PaymentStatus.pending
                      ? null
                      : (value) => setState(() => _cashReceived = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppTheme.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text(
                    _booking.paymentStatus == PaymentStatus.paid
                        ? 'Payment already recorded'
                        : "I've received ${Formatters.audCents(_booking.totalCents)}${cash ? ' in cash' : ''}",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface),
                  ),
                  subtitle: _booking.paymentStatus == PaymentStatus.pending
                      ? Text(
                          _cashReceived
                              ? 'The booking will show as paid.'
                              : 'You can record the payment later from this booking.',
                          style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6)),
                        )
                      : null,
                ),
              ),
            if (_takesReason) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _reason,
                enabled: !_busy,
                maxLength: _maxReasonLength,
                maxLines: 3,
                minLines: 2,
                autofocus: _needsReason,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: _needsReason
                      ? 'Reason for ${_booking.clientName}'
                      : 'Message to ${_booking.clientName} (optional)',
                  hintText: _needsReason
                      ? "e.g. I'm unwell. So sorry for the trouble!"
                      : 'e.g. Fully booked that day. Could you try Thursday?',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.destructive),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: canSubmit ? _submit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: _destructive ? Colors.white : scheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                ),
                child: _busy
                    ? SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: _destructive ? Colors.white : scheme.surface,
                        ),
                      )
                    : Text(copy.confirm),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurface,
                minimumSize: const Size(0, 48),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: Text(widget.action == ProviderBookingAction.complete ? 'Not yet' : 'Go back'),
            ),
          ],
        ),
      ),
    );
  }
}
