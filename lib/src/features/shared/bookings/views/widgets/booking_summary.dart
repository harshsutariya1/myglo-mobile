import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';

/// Bordered white card used for every block of booking details.
class BookingSectionCard extends StatelessWidget {
  const BookingSectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

/// Small uppercase heading above a [BookingSectionCard].
class BookingSectionLabel extends StatelessWidget {
  const BookingSectionLabel(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// One line of booking details: icon, title, optional detail and an
/// optional "Change" link.
class BookingDetailRow extends StatelessWidget {
  const BookingDetailRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onChange,
    this.changeLabel = 'Change',
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onChange;
  final String changeLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 19, color: scheme.secondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 1),
              Text(
                title,
                style: TextStyle(fontSize: 15, height: 1.3, fontWeight: FontWeight.w700, color: scheme.onSurface),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(fontSize: 13.5, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        if (onChange != null)
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              foregroundColor: scheme.secondary,
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
            child: Text(changeLabel),
          ),
      ],
    );
  }
}

/// A priced line in a [PriceBreakdown].
typedef PriceLine = ({String label, String? detail, int cents});

/// Itemised prices with subtotal, fee and total.
///
/// Myglo charges clients no booking fee (the platform's commission, if any,
/// is settled with the provider), so for clients the fee line always reads
/// "Free". Providers pass [platformFeeCents] to see what they earn instead.
class PriceBreakdown extends StatelessWidget {
  const PriceBreakdown({super.key, required this.lines, required this.totalCents, this.footnote, this.platformFeeCents});

  final List<PriceLine> lines;
  final int totalCents;
  final String? footnote;

  /// Provider view: Myglo's commission on the booking. Null for clients.
  final int? platformFeeCents;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final subtotal = lines.fold<int>(0, (sum, line) => sum + line.cents);
    final divider = Divider(height: 24, thickness: 1, color: scheme.onSurface.withValues(alpha: 0.07));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.label,
                        style: TextStyle(fontSize: 15, height: 1.3, fontWeight: FontWeight.w600, color: scheme.onSurface),
                      ),
                      if (line.detail != null)
                        Text(line.detail!, style: TextStyle(fontSize: 12.5, color: muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  Formatters.audCents(line.cents),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface),
                ),
              ],
            ),
          ),
        divider,
        if (platformFeeCents case final fee?) ...[
          _AmountRow(label: 'Client pays', value: Formatters.audCents(totalCents), style: _style(muted)),
          const SizedBox(height: 6),
          _AmountRow(
            label: 'Myglo fee',
            value: fee == 0 ? 'Free' : '−${Formatters.audCents(fee)}',
            style: _style(muted),
            valueStyle: fee == 0 ? _style(AppTheme.success).copyWith(fontWeight: FontWeight.w800) : null,
          ),
          divider,
          _AmountRow(
            label: 'You earn',
            value: Formatters.audCents(totalCents - fee),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: scheme.onSurface),
          ),
        ] else ...[
          _AmountRow(label: 'Subtotal', value: Formatters.audCents(subtotal), style: _style(muted)),
          const SizedBox(height: 6),
          _AmountRow(
            label: 'Booking fee',
            value: 'Free',
            style: _style(muted),
            valueStyle: _style(AppTheme.success).copyWith(fontWeight: FontWeight.w800),
          ),
          divider,
          _AmountRow(
            label: 'Total',
            value: Formatters.audCents(totalCents),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: scheme.onSurface),
          ),
        ],
        if (footnote != null) ...[
          const SizedBox(height: 6),
          Text(footnote!, style: TextStyle(fontSize: 12.5, height: 1.4, color: muted)),
        ],
      ],
    );
  }

  static TextStyle _style(Color color) => TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color);
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.value, required this.style, this.valueStyle});

  final String label;
  final String value;
  final TextStyle style;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: valueStyle ?? style),
      ],
    );
  }
}

/// A soft callout for policies and notices.
class BookingNotice extends StatelessWidget {
  const BookingNotice({super.key, required this.icon, required this.title, required this.body, this.color});

  final IconData icon;
  final String title;
  final String body;

  /// Accent; defaults to the brand secondary.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final accent = color ?? scheme.secondary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(fontSize: 13.5, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
