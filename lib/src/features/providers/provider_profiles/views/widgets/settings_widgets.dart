import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/soon_badge.dart';

/// Page background for inset-grouped settings: a faint tint so the white
/// cards read as grouped.
Color settingsBackground(BuildContext context) {
  final scheme = context.colorScheme;
  return Color.alphaBlend(scheme.onSurface.withValues(alpha: 0.025), scheme.surface);
}

/// Bordered card used for every settings group.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// A titled group of [SettingsTile]s separated by inset hairlines.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.children, this.footer});

  final String title;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final divider = Divider(
      height: 1,
      thickness: 1,
      indent: SettingsTile.textInset,
      color: scheme.onSurface.withValues(alpha: 0.06),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          SettingsCard(
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) divider,
                  children[i],
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                footer!,
                style: TextStyle(fontSize: 12.5, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.5)),
              ),
            ),
        ],
      ),
    );
  }
}

/// One settings row: tinted icon, title, optional subtitle and a trailing
/// chevron, switch, badge or "Soon" tag.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.badge,
    this.soon = false,
    this.iconColor,
  });

  /// Left edge of the title text, used to inset dividers.
  static const double textInset = 16 + 36 + 14;

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  /// Replaces the default chevron (e.g. a switch or spinner).
  final Widget? trailing;

  /// Status pill shown before the chevron (e.g. "Verification pending").
  final Widget? badge;

  /// Marks a row whose feature isn't live yet: muted, with a "Soon" tag.
  final bool soon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final tint = iconColor ?? scheme.secondary;
    final chevron = Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withValues(alpha: 0.3));

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: soon ? 0.06 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: soon ? tint.withValues(alpha: 0.5) : tint),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface.withValues(alpha: soon ? 0.6 : 1),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, height: 1.3, color: scheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (badge != null) ...[badge!, const SizedBox(width: 4)],
              if (soon) const SoonBadge() else trailing ?? chevron,
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded status pill, e.g. an amber "Unverified" tag.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, this.icon, this.leading});

  final String label;
  final Color color;
  final IconData? icon;

  /// Custom leading widget (e.g. a pulsing dot); overrides [icon].
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null)
            leading!
          else if (icon != null)
            Icon(icon, size: 14, color: color),
          if (leading != null || icon != null) const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color.lerp(color, Colors.black, 0.35)),
          ),
        ],
      ),
    );
  }
}

/// Small dot with a repeating halo, signalling a live status.
class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key, required this.color, this.size = 8, this.animate = true});

  final Color color;
  final double size;
  final bool animate;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  // Respect "reduce motion": keep the dot, drop the halo.
  bool get _shouldAnimate => widget.animate && !MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (_shouldAnimate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (!_shouldAnimate) return SizedBox.square(dimension: widget.size * 2, child: Center(child: dot));

    return SizedBox.square(
      dimension: widget.size * 2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size * (1 + t),
                height: widget.size * (1 + t),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.45 * (1 - t)),
                  shape: BoxShape.circle,
                ),
              ),
              child!,
            ],
          );
        },
        child: dot,
      ),
    );
  }
}
