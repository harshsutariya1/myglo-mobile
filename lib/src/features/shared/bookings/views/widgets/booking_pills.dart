import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../models/booking_enums.dart';

/// Rounded tinted label, the shared look of status and payment pills.
class BookingPill extends StatelessWidget {
  const BookingPill({super.key, required this.label, required this.color, this.icon, this.dense = false});

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: _ink),
            SizedBox(width: dense ? 4 : 5),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: dense ? 11 : 12, fontWeight: FontWeight.w700, color: _ink),
          ),
        ],
      ),
    );
  }

  /// Darkened for contrast on the pale tint.
  Color get _ink => Color.lerp(color, Colors.black, 0.35)!;
}

/// Colour and icon for each booking status.
({Color color, IconData icon}) bookingStatusStyle(BookingStatus status, ColorScheme scheme) => switch (status) {
      BookingStatus.pending => (color: AppTheme.warning, icon: Icons.hourglass_top_rounded),
      BookingStatus.confirmed => (color: AppTheme.success, icon: Icons.check_circle_rounded),
      BookingStatus.completed => (color: AppTheme.success, icon: Icons.done_all_rounded),
      BookingStatus.declined => (color: AppTheme.destructive, icon: Icons.block_rounded),
      BookingStatus.cancelled => (color: AppTheme.destructive, icon: Icons.event_busy_rounded),
      BookingStatus.noShow => (color: AppTheme.destructive, icon: Icons.person_off_rounded),
      BookingStatus.expired => (color: scheme.onSurface.withValues(alpha: 0.55), icon: Icons.timer_off_rounded),
    };

class BookingStatusPill extends StatelessWidget {
  const BookingStatusPill({super.key, required this.status, this.dense = false});

  final BookingStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final style = bookingStatusStyle(status, context.colorScheme);
    return Semantics(
      label: 'Status: ${status.label}',
      excludeSemantics: true,
      child: BookingPill(label: status.label, color: style.color, icon: style.icon, dense: dense),
    );
  }
}

/// `Pending (Cash)`, `Paid (Cash)`…
class PaymentStatusPill extends StatelessWidget {
  const PaymentStatusPill({super.key, required this.method, required this.status, this.dense = false});

  final PaymentMethod method;
  final PaymentStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PaymentStatus.pending => AppTheme.burntOrange,
      PaymentStatus.paid => AppTheme.success,
      PaymentStatus.refunded || PaymentStatus.voided => context.colorScheme.onSurface.withValues(alpha: 0.55),
    };
    return Semantics(
      label: 'Payment: ${paymentStatusLabel(method, status)}',
      excludeSemantics: true,
      child: BookingPill(
        label: paymentStatusLabel(method, status),
        color: color,
        icon: method == PaymentMethod.cash ? Icons.payments_outlined : Icons.credit_card_rounded,
        dense: dense,
      ),
    );
  }
}
