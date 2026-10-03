import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/snackbar_utils.dart';
import '../../../../../core/widgets/soon_badge.dart';
import '../../../../shared/services/views/widgets/service_tile.dart';
import '../../controllers/provider_services_controller.dart';
import '../../models/service_model.dart';
import '../screens/add_service_screen.dart';

enum _ServiceAction { edit, duplicate, pause, delete }

/// Three-dot menu shown on the provider's own service tiles.
class ServiceOwnerMenu extends StatelessWidget {
  const ServiceOwnerMenu({super.key, required this.service});

  final ServiceModel service;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SizedBox.square(
      dimension: ServiceTileMetrics.actionSize,
      child: PopupMenuButton<_ServiceAction>(
        tooltip: 'Options for ${service.name}',
        padding: EdgeInsets.zero,
        icon: Icon(Icons.more_vert_rounded, color: scheme.onSurface.withValues(alpha: 0.6)),
        position: PopupMenuPosition.under,
        constraints: const BoxConstraints(minWidth: 230, maxWidth: 300),
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.06)),
        ),
        onSelected: (action) => _onSelected(context, action),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: _ServiceAction.edit,
            child: _MenuRow(icon: Icons.edit_outlined, label: 'Edit details'),
          ),
          const PopupMenuItem(
            value: _ServiceAction.duplicate,
            child: _MenuRow(icon: Icons.content_copy_rounded, label: 'Duplicate as new'),
          ),
          const PopupMenuItem(
            value: _ServiceAction.pause,
            child: _MenuRow(icon: Icons.visibility_off_outlined, label: 'Pause service', soon: true),
          ),
          const PopupMenuDivider(height: 1),
          const PopupMenuItem(
            value: _ServiceAction.delete,
            child: _MenuRow(icon: Icons.delete_outline_rounded, label: 'Delete service', destructive: true),
          ),
        ],
      ),
    );
  }

  void _onSelected(BuildContext context, _ServiceAction action) {
    switch (action) {
      case _ServiceAction.edit:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddServiceScreen.edit(service)));
      case _ServiceAction.duplicate:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddServiceScreen.duplicate(service)));
      case _ServiceAction.pause:
        context.showComingSoon('Pausing a service');
      case _ServiceAction.delete:
        showDeleteServiceSheet(context, service);
    }
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.destructive = false, this.soon = false});

  final IconData icon;
  final String label;
  final bool destructive;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppTheme.destructive : context.colorScheme.onSurface;
    return Row(
      children: [
        Icon(icon, size: 20, color: destructive ? color : color.withValues(alpha: 0.75)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: color),
          ),
        ),
        if (soon) ...[
          const SizedBox(width: 8),
          const SoonBadge(),
        ],
      ],
    );
  }
}

/// Bottom confirmation before deleting [service]. Never deletes on one tap.
Future<void> showDeleteServiceSheet(BuildContext context, ServiceModel service) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _DeleteServiceSheet(service: service, hostContext: context),
  );
}

class _DeleteServiceSheet extends ConsumerStatefulWidget {
  const _DeleteServiceSheet({required this.service, required this.hostContext});

  final ServiceModel service;

  /// Context of the screen that opened the sheet, for the result snackbar.
  final BuildContext hostContext;

  @override
  ConsumerState<_DeleteServiceSheet> createState() => _DeleteServiceSheetState();
}

class _DeleteServiceSheetState extends ConsumerState<_DeleteServiceSheet> {
  bool _deleting = false;
  bool _failed = false;

  Future<void> _delete() async {
    setState(() {
      _deleting = true;
      _failed = false;
    });
    final ok = await ref.read(serviceActionsProvider).delete(widget.service);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      if (widget.hostContext.mounted) {
        widget.hostContext.showAppSnackBar('"${widget.service.name}" deleted');
      }
    } else {
      setState(() {
        _deleting = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    const buttonText = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.destructive.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded, color: AppTheme.destructive),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Delete ${widget.service.name}?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'This will remove the service from your public profile. Existing confirmed '
              'appointments will not be affected, and posts tagged with it stay up without the tag.',
              style: TextStyle(fontSize: 14.5, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.65)),
            ),
            if (_failed) ...[
              const SizedBox(height: 12),
              Text(
                "Couldn't delete the service. Check your connection and try again.",
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.destructive),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _deleting ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.onSurface,
                        side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.3), width: 1.5),
                        shape: shape,
                        textStyle: buttonText,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _deleting ? null : _delete,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.destructive,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppTheme.destructive.withValues(alpha: 0.5),
                        disabledForegroundColor: Colors.white,
                        shape: shape,
                        textStyle: buttonText,
                      ),
                      child: _deleting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Delete'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
