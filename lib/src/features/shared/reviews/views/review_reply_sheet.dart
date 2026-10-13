import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../controllers/reviews_controllers.dart';
import '../models/review.dart';
import '../models/review_failure.dart';
import 'widgets/star_rating.dart';

/// Lets the provider write, edit or remove their public reply to [review].
/// Returns true when something was saved.
Future<bool> showReviewReplySheet(BuildContext context, {required Review review}) async {
  final confirmation = await showModalBottomSheet<String>(
    context: context,
    // Above the tab bar.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _ReplySheet(review: review),
  );
  if (confirmation == null) return false;
  if (context.mounted) context.showAppSnackBar(confirmation);
  return true;
}

class _ReplySheet extends ConsumerStatefulWidget {
  const _ReplySheet({required this.review});

  final Review review;

  @override
  ConsumerState<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends ConsumerState<_ReplySheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.review.reply ?? '');
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save({bool remove = false}) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(reviewActionsProvider).reply(widget.review, remove ? '' : _controller.text);
      HapticFeedback.lightImpact();
      final review = widget.review;
      if (mounted) {
        Navigator.of(context).pop(
          remove
              ? 'Reply removed'
              : review.hasReply
                  ? 'Reply updated'
                  : 'Reply posted. ${review.reviewerName} has been notified.',
        );
      }
    } on ReviewFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final review = widget.review;
    final text = _controller.text.trim();
    final unchanged = text == (review.reply ?? '');

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            review.hasReply ? 'Edit your reply' : 'Reply to ${review.reviewerName}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: scheme.onSurface),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              StarRating(rating: review.rating.toDouble(), size: 15),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.body ?? 'No written review',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, color: scheme.onSurface.withValues(alpha: 0.65)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: AppConfig.reviewMaxLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Thank them, or respond to their feedback. Everyone can see your reply.',
              errorText: _error,
              errorMaxLines: 3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (review.hasReply)
                TextButton(
                  onPressed: _saving ? null : () => _save(remove: true),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.destructive),
                  child: const Text('Remove reply'),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _saving || text.isEmpty || unchanged ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  minimumSize: const Size(120, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onPrimary))
                    : Text(review.hasReply ? 'Save' : 'Post reply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
