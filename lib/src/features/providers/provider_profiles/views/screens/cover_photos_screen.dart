import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/config/app_config.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/app_logger.dart';
import '../../../../../core/widgets/dashed_border.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../../core/widgets/snackbar_utils.dart';
import '../../../../shared/cover_photos/views/cover_carousel.dart';
import '../../controllers/cover_photos_controller.dart';

/// Where a provider manages the photos across the top of their profile:
/// add up to five, reorder them, pick the main one, remove any. Every change
/// is saved straight away.
class CoverPhotosScreen extends ConsumerStatefulWidget {
  const CoverPhotosScreen({super.key});

  @override
  ConsumerState<CoverPhotosScreen> createState() => _CoverPhotosScreenState();
}

class _CoverPhotosScreenState extends ConsumerState<CoverPhotosScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(coverPhotosControllerProvider.notifier).tidyUp();
    });
  }

  CoverPhotosController get _controller => ref.read(coverPhotosControllerProvider.notifier);

  void _report(String? problem) {
    if (problem != null && mounted) context.showAppSnackBar(problem, isError: true);
  }

  Future<void> _add() async {
    final remaining = ref.read(coverPhotosControllerProvider).remaining;
    if (remaining <= 0 || _picking) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(remaining > 1 ? 'Choose up to $remaining photos' : 'Choose a photo'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;

    setState(() => _picking = true);
    List<XFile> picked;
    try {
      if (source == ImageSource.gallery && remaining > 1) {
        picked = await _picker.pickMultiImage(limit: remaining, maxWidth: 3000, maxHeight: 3000, imageQuality: 92);
      } else {
        final file = await _picker.pickImage(source: source, maxWidth: 3000, maxHeight: 3000, imageQuality: 92);
        picked = [?file];
      }
    } on PlatformException catch (e, st) {
      AppLogger.w('Picking cover photos failed', tag: 'CoverPhotos', error: e, stackTrace: st);
      if (mounted) {
        context.showAppSnackBar(
          source == ImageSource.camera
              ? 'Allow camera access in Settings to take a photo.'
              : 'Allow photo access in Settings to choose photos.',
          isError: true,
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _picking = false);
    }
    if (picked.isEmpty || !mounted) return;
    HapticFeedback.selectionClick();
    _report(await _controller.add([for (final file in picked) File(file.path)]));
  }

  Future<void> _remove(String url, {required bool main}) async {
    final last = ref.read(coverPhotosControllerProvider).slots.length == 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this photo?'),
        content: Text(last
            ? 'Clients will see the Myglo artwork until you add another.'
            : main
                ? 'The next photo becomes your main cover.'
                : "It'll be removed from your profile straight away."),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.destructive, foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _report(await _controller.remove(url));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final state = ref.watch(coverPhotosControllerProvider);
    final slots = state.slots;
    final main = slots.isEmpty ? null : slots.first;
    final busy = state.uploading || _picking;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Cover photos'),
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: state.saving || state.uploading
                ? Padding(
                    key: const ValueKey('saving'),
                    padding: const EdgeInsets.only(right: 18),
                    child: Row(
                      children: [
                        SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          state.uploading ? 'Uploading' : 'Saving',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('idle')),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Show clients your space and your best work. Add up to ${AppConfig.coverPhotosMax} photos; '
                    'the first one is your main cover.',
                    style: TextStyle(fontSize: 14, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.65)),
                  ),
                  const SizedBox(height: 16),
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: main == null
                        ? _EmptyCover(onAdd: busy ? null : _add)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _SlotImage(slot: main),
                                Positioned(
                                  left: 12,
                                  top: 12,
                                  child: _Badge(label: 'Main cover', icon: Icons.star_rounded, color: scheme.primary),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Text(
                        'YOUR PHOTOS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${slots.length} of ${AppConfig.coverPhotosMax}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                  if (slots.length > 1) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Drag to reorder.',
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.5)),
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverReorderableList(
              itemCount: slots.length,
              onReorder: (from, to) async {
                // ReorderableList reports the destination as if the item
                // were still in place.
                final target = to > from ? to - 1 : to;
                HapticFeedback.selectionClick();
                _report(await _controller.reorder(from, target));
              },
              proxyDecorator: (child, _, _) => Material(
                color: Colors.transparent,
                elevation: 8,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(18),
                child: child,
              ),
              itemBuilder: (context, index) {
                final slot = slots[index];
                return _SlotRow(
                  key: ValueKey(slot.id),
                  slot: slot,
                  index: index,
                  canReorder: !state.uploading && slots.length > 1,
                  onMakeMain: slot.url == null || index == 0
                      ? null
                      : () async => _report(await _controller.makeMain(slot.url!)),
                  onRemove: slot.url == null ? null : () => _remove(slot.url!, main: index == 0),
                );
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            sliver: SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, size: 18, color: scheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bright, landscape photos look best. Show your chairs, your space and finished looks.',
                      style: TextStyle(fontSize: 12.5, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton.icon(
          onPressed: state.remaining > 0 && !busy ? _add : null,
          icon: busy
              ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.surface))
              : const Icon(Icons.add_photo_alternate_outlined),
          label: Text(state.remaining > 0
              ? 'Add photos · ${state.remaining} left'
              : 'All ${AppConfig.coverPhotosMax} photos added'),
          style: FilledButton.styleFrom(
            backgroundColor: scheme.onSurface,
            foregroundColor: scheme.surface,
            minimumSize: const Size(0, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _EmptyCover extends StatelessWidget {
  const _EmptyCover({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return DashedBorder(
      color: scheme.primary.withValues(alpha: 0.6),
      radius: 20,
      child: Material(
        color: scheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onAdd,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
                child: Icon(Icons.add_photo_alternate_outlined, size: 28, color: scheme.primary),
              ),
              const SizedBox(height: 10),
              Text(
                'Add your first cover photo',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scheme.onSurface),
              ),
              const SizedBox(height: 2),
              Text(
                'Until then, clients see the Myglo artwork.',
                style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.55)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotImage extends StatelessWidget {
  const _SlotImage({required this.slot});

  final CoverPhotoSlot slot;

  @override
  Widget build(BuildContext context) {
    final url = slot.url;
    final image = url != null
        ? CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, _) => const Shimmer(child: SkeletonBox(borderRadius: 0)),
            errorWidget: (_, _, _) => Image.asset(defaultCoverAsset, fit: BoxFit.cover),
          )
        : Image.file(File(slot.localPath!), fit: BoxFit.cover, cacheWidth: 600);
    if (!slot.isUploading) return image;
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
        const Center(
          child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    super.key,
    required this.slot,
    required this.index,
    required this.canReorder,
    required this.onMakeMain,
    required this.onRemove,
  });

  final CoverPhotoSlot slot;
  final int index;
  final bool canReorder;
  final VoidCallback? onMakeMain;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final isMain = index == 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 112, height: 63, child: _SlotImage(slot: slot)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMain ? 'Main cover' : 'Photo ${index + 1}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    slot.isUploading ? 'Uploading…' : (isMain ? 'Shown first' : 'In your cover carousel'),
                    style: TextStyle(fontSize: 12.5, color: muted),
                  ),
                ],
              ),
            ),
            if (!slot.isUploading)
              PopupMenuButton<String>(
                tooltip: 'Photo options',
                icon: Icon(Icons.more_horiz_rounded, color: muted),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (value) => switch (value) {
                  'main' => onMakeMain?.call(),
                  'remove' => onRemove?.call(),
                  _ => null,
                },
                itemBuilder: (_) => [
                  if (onMakeMain != null)
                    const PopupMenuItem(
                      value: 'main',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.star_outline_rounded),
                        title: Text('Make main cover'),
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline_rounded, color: AppTheme.destructive),
                      title: Text('Remove', style: TextStyle(color: AppTheme.destructive)),
                    ),
                  ),
                ],
              ),
            if (canReorder)
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Icon(Icons.drag_indicator_rounded, color: muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
