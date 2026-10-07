import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

/// The steps of the booking flow, in order.
enum BookingStep {
  services('Services'),
  dateTime('Date & time'),
  location('Location'),
  review('Review'),
  payment('Payment');

  const BookingStep(this.label);

  final String label;

  int get number => index + 1;
}

/// Segmented progress under the app bar: completed steps filled, the current
/// one in the brand colour.
class BookingProgressBar extends StatelessWidget implements PreferredSizeWidget {
  const BookingProgressBar({super.key, required this.step});

  final BookingStep step;

  static const Duration _animation = Duration(milliseconds: 260);

  @override
  Size get preferredSize => const Size.fromHeight(34);

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final total = BookingStep.values.length;
    return Semantics(
      label: 'Step ${step.number} of $total, ${step.label}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (final s in BookingStep.values) ...[
                  if (s.index > 0) const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedContainer(
                      duration: _animation,
                      curve: Curves.easeOutCubic,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: s.index < step.index
                            ? scheme.onSurface
                            : s == step
                                ? scheme.primary
                                : scheme.onSurface.withValues(alpha: 0.09),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 7),
            Text(
              'STEP ${step.number} OF $total',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: scheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// App bar title with the provider's name underneath.
class BookingAppBarTitle extends StatelessWidget {
  const BookingAppBarTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: scheme.onSurface)),
        if (subtitle != null && subtitle!.isNotEmpty)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface.withValues(alpha: 0.55)),
          ),
      ],
    );
  }
}

/// Shared chrome for the steps after service selection.
class BookingFlowScaffold extends StatelessWidget {
  const BookingFlowScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.body,
    this.subtitle,
    this.footer,
    this.onBack,
  });

  final BookingStep step;
  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? footer;

  /// Overrides the default back behaviour.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 0,
        leading: BackButton(onPressed: onBack),
        title: BookingAppBarTitle(title: title, subtitle: subtitle),
        bottom: BookingProgressBar(step: step),
      ),
      body: body,
      bottomNavigationBar: footer,
    );
  }
}

/// Sticky footer: a summary on the left and the primary action on the right.
class BookingFooter extends StatelessWidget {
  const BookingFooter({
    super.key,
    required this.actionLabel,
    required this.onAction,
    this.summary,
    this.busy = false,
    this.icon = Icons.arrow_forward_rounded,
  });

  final String actionLabel;

  /// Null disables the button.
  final VoidCallback? onAction;
  final Widget? summary;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: scheme.onSurface.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, -6)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.paddingOf(context).bottom),
        child: Row(
          children: [
            if (summary != null) ...[
              Expanded(child: summary!),
              const SizedBox(width: 12),
            ],
            if (summary == null)
              Expanded(child: _ActionButton(label: actionLabel, onPressed: onAction, busy: busy, icon: icon))
            else
              _ActionButton(label: actionLabel, onPressed: onAction, busy: busy, icon: icon),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed, required this.busy, required this.icon});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.onSurface,
          foregroundColor: scheme.surface,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: busy ? 0.85 : 0.12),
          disabledForegroundColor: busy ? scheme.surface : scheme.onSurface.withValues(alpha: 0.38),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: busy
              ? SizedBox.square(
                  key: const ValueKey('busy'),
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: scheme.surface),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label),
                    if (icon != null) ...[const SizedBox(width: 6), Icon(icon, size: 18)],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Two-line footer summary: a small caption over a bold value.
class BookingFooterSummary extends StatelessWidget {
  const BookingFooterSummary({super.key, required this.caption, required this.value});

  final String caption;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: scheme.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.centerLeft,
            children: [...previous, ?current],
          ),
          // Shrinks rather than cutting off, so a whole time range such as
          // "10:00 am – 11:30 am" stays readable beside the button.
          child: FittedBox(
            key: ValueKey(value),
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(fontSize: 18, height: 1.2, fontWeight: FontWeight.w800, color: scheme.onSurface),
            ),
          ),
        ),
      ],
    );
  }
}
