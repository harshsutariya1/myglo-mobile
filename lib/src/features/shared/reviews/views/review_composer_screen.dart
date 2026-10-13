import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../bookings/models/booking.dart';
import '../../bookings/views/widgets/booking_card.dart' show PersonAvatar;
import '../controllers/reviews_controllers.dart';
import '../models/review.dart';
import '../models/review_failure.dart';
import 'widgets/star_rating.dart';

/// What the composer did, for the screen that opened it.
enum ReviewComposerResult { saved, deleted }

/// Opens the composer for [booking] (editing [existing] if given) and shows
/// the outcome. Returns what happened, or null if the client backed out.
Future<ReviewComposerResult?> openReviewComposer(
  BuildContext context, {
  required Booking booking,
  Review? existing,
  int initialRating = 0,
}) async {
  // Full screen, above the tab bar (its action bar sits at the bottom).
  final result = await Navigator.of(context, rootNavigator: true).push<ReviewComposerResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ReviewComposerScreen(booking: booking, existing: existing, initialRating: initialRating),
    ),
  );
  if (!context.mounted || result == null) return result;
  context.showAppSnackBar(switch (result) {
    ReviewComposerResult.saved => existing == null ? 'Thanks! Your review is live.' : 'Review updated',
    ReviewComposerResult.deleted => 'Review deleted',
  });
  return result;
}

/// Where a client rates a completed booking: stars, optional words and up to
/// [AppConfig.reviewMaxPhotos] photos (shared on Discover with the service
/// tagged). Also edits or deletes their existing review.
class ReviewComposerScreen extends ConsumerStatefulWidget {
  const ReviewComposerScreen({super.key, required this.booking, this.existing, this.initialRating = 0});

  final Booking booking;
  final Review? existing;
  final int initialRating;

  @override
  ConsumerState<ReviewComposerScreen> createState() => _ReviewComposerScreenState();
}

class _ReviewComposerScreenState extends ConsumerState<ReviewComposerScreen> {
  final _picker = ImagePicker();
  late final TextEditingController _body = TextEditingController(text: widget.existing?.body ?? '');
  late int _rating = widget.existing?.rating ?? widget.initialRating.clamp(0, 5);
  late final List<String> _keptPhotos = [...?widget.existing?.photoUrls];
  final List<File> _newPhotos = [];
  bool _saving = false;
  bool _deleting = false;

  Review? get _existing => widget.existing;
  bool get _busy => _saving || _deleting;
  int get _photoCount => _keptPhotos.length + _newPhotos.length;

  bool get _dirty {
    final existing = _existing;
    if (existing == null) return _rating > 0 || _body.text.trim().isNotEmpty || _newPhotos.isNotEmpty;
    return _rating != existing.rating ||
        _body.text.trim() != (existing.body ?? '') ||
        _newPhotos.isNotEmpty ||
        _keptPhotos.length != existing.photoUrls.length;
  }

  @override
  void initState() {
    super.initState();
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final remaining = AppConfig.reviewMaxPhotos - _photoCount;
    if (remaining <= 0) {
      context.showAppSnackBar('A review can have up to ${AppConfig.reviewMaxPhotos} photos');
      return;
    }
    try {
      // `limit` must be at least 2, so a single free slot uses the single picker.
      final picked = remaining == 1
          ? [?await _picker.pickImage(source: ImageSource.gallery)]
          : await _picker.pickMultiImage(limit: remaining);
      if (picked.isEmpty || !mounted) return;
      setState(() => _newPhotos.addAll(picked.take(remaining).map((file) => File(file.path))));
    } catch (e, st) {
      AppLogger.e('Review photo picker failed', tag: 'ReviewComposer', error: e, stackTrace: st);
      if (mounted) context.showAppSnackBar("Couldn't open your photos. Check photo access in Settings.", isError: true);
    }
  }

  Future<void> _submit() async {
    if (_busy || _rating == 0) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref.read(reviewActionsProvider).submit(
            bookingId: widget.booking.id,
            providerId: widget.booking.providerId!,
            rating: _rating,
            body: _body.text,
            originalPhotoUrls: _existing?.photoUrls ?? const [],
            keptPhotoUrls: _keptPhotos,
            newPhotos: _newPhotos,
          );
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(ReviewComposerResult.saved);
    } on ReviewFailure catch (failure) {
      if (mounted) context.showAppSnackBar(failure.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = _existing;
    if (existing == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your review?'),
        content: Text(
          existing.photoUrls.isEmpty
              ? "It will be removed from ${widget.booking.providerName}'s profile. You can review this visit again later."
              : "It will be removed from ${widget.booking.providerName}'s profile, and its photos from Discover. "
                  'You can review this visit again later.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.destructive),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(reviewActionsProvider).delete(existing);
      if (mounted) Navigator.of(context).pop(ReviewComposerResult.deleted);
    } on ReviewFailure catch (failure) {
      if (mounted) context.showAppSnackBar(failure.message, isError: true);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_existing == null ? 'Discard your review?' : 'Discard your changes?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep editing')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.destructive),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final booking = widget.booking;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final serviceTagged = booking.items.firstOrNull?.name;
    final canSubmit = !_busy && _rating > 0 && (_existing == null || _dirty);

    return PopScope(
      canPop: !_busy && !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _busy) return;
        if (await _confirmDiscard() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          backgroundColor: scheme.surface,
          surfaceTintColor: Colors.transparent,
          title: Text(_existing == null ? 'Rate your visit' : 'Edit your review'),
          actions: [
            if (_existing != null)
              IconButton(
                tooltip: 'Delete review',
                onPressed: _busy ? null : _delete,
                icon: _deleting
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Row(
                children: [
                  PersonAvatar(name: booking.providerName, url: booking.providerAvatarUrl, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.providerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: scheme.onSurface),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${booking.servicesSummary} · ${Formatters.dateShort(booking.startsAtLocal)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  'How was your visit?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: scheme.onSurface),
                ),
              ),
              const SizedBox(height: 10),
              Center(child: StarRatingInput(value: _rating, onChanged: (value) => setState(() => _rating = value))),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  _rating == 0 ? 'Tap a star to rate' : StarRatingInput.labels[_rating - 1],
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: muted),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _body,
                minLines: 4,
                maxLines: 8,
                maxLength: AppConfig.reviewMaxLength,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Your review (optional)',
                  alignLabelWithHint: true,
                  hintText: 'What did you love? Anything others should know?',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Photos (optional)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                serviceTagged == null
                    ? 'Photos are shared publicly on Discover, tagged with ${booking.providerName}.'
                    : 'Photos are shared publicly on Discover, tagged with ${booking.providerName} and $serviceTagged.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: muted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final url in _keptPhotos)
                    _PhotoThumb(
                      image: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => const Shimmer(child: SkeletonBox(borderRadius: 0)),
                        errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined),
                      ),
                      onRemove: () => setState(() => _keptPhotos.remove(url)),
                    ),
                  for (final file in _newPhotos)
                    _PhotoThumb(
                      image: Image.file(file, fit: BoxFit.cover, cacheWidth: 240),
                      onRemove: () => setState(() => _newPhotos.remove(file)),
                    ),
                  if (_photoCount < AppConfig.reviewMaxPhotos) _AddPhotoTile(onTap: _pickPhotos),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: canSubmit ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              child: _saving
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary),
                        ),
                        const SizedBox(width: 12),
                        Text(_newPhotos.isEmpty ? 'Saving…' : 'Uploading photos…'),
                      ],
                    )
                  : Text(_existing == null ? 'Post review' : 'Save changes'),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.image, required this.onRemove});

  final Widget image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 80,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: image),
          Positioned(
            top: 2,
            right: 2,
            child: Semantics(
              button: true,
              label: 'Remove photo',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Semantics(
      button: true,
      label: 'Add photos',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.onSurface.withValues(alpha: 0.15)),
            color: scheme.onSurface.withValues(alpha: 0.03),
          ),
          child: Icon(Icons.add_photo_alternate_outlined, color: scheme.secondary),
        ),
      ),
    );
  }
}
