import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../models/admin_failure.dart';

/// "Tue 4 Nov, 9:30 am" in the admin's own time zone. Admin screens show
/// device-local times (admins may not be in Queensland); booking screens
/// keep showing the provider's time.
String adminDateTime(DateTime time) => Formatters.dateTimeShort(time.toLocal());

/// "4 Nov 2026".
String adminDate(DateTime time) {
  final local = time.toLocal();
  return '${local.day} ${Formatters.monthShort(local)} ${local.year}';
}

/// A titled group of rows on an admin detail screen.
class AdminSection extends StatelessWidget {
  const AdminSection({super.key, required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scheme.onSurface),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 6),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// A label and its value.
class AdminInfoRow extends StatelessWidget {
  const AdminInfoRow({super.key, required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 13.5, color: scheme.onSurface.withValues(alpha: 0.6))),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// A headline number on the admin home.
class AdminStatTile extends StatelessWidget {
  const AdminStatTile({super.key, required this.label, required this.value, required this.icon, this.onTap, this.alert = false});

  final String label;
  final int value;
  final IconData icon;
  final VoidCallback? onTap;

  /// Draws attention (e.g. failed jobs).
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final accent = alert && value > 0 ? AppTheme.destructive : scheme.secondary;
    return Material(
      color: alert && value > 0 ? AppTheme.destructive.withValues(alpha: 0.06) : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(height: 10),
              Text(
                Formatters.compactCount(value),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: scheme.onSurface),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-area error with a retry, for an admin screen that couldn't load.
class AdminErrorView extends StatelessWidget {
  const AdminErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40, color: scheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              AdminFailure.from(error).message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, color: scheme.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

/// A small coloured label (role, status…).
class AdminChip extends StatelessWidget {
  const AdminChip({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tint)),
    );
  }
}

/// Asks for the reason an admin change is being made (audited with it).
/// Returns the trimmed reason, or null if cancelled.
Future<String?> askAdminReason(BuildContext context, {required String title, String? summary}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _ReasonDialog(title: title, summary: summary),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, this.summary});

  final String title;
  final String? summary;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => _controller.text.trim().length >= 3;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.summary != null) ...[
            Text(widget.summary!, style: const TextStyle(fontSize: 14, height: 1.4)),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Why is this change being made?',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _valid ? () => Navigator.of(context).pop(_controller.text.trim()) : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
