import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../controllers/blocks_controller.dart';
import '../models/blocks_repository.dart';

/// Asks before blocking [userId] ([name] is how they're shown), then blocks
/// them. Returns whether they were blocked, so the caller can leave a page
/// that shows only their content.
Future<bool> confirmAndBlockUser(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String name,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Block $name?'),
      content: const Text(
        "You won't see each other's posts or comments, you can't follow each other, and you can't make new "
        "bookings together. Bookings you already have aren't affected.\n\n"
        "They won't be told. You can unblock them in Settings at any time.",
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.destructive),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  try {
    await ref.read(blockActionsProvider).block(userId);
    HapticFeedback.mediumImpact();
    if (context.mounted) context.showAppSnackBar('$name is blocked');
    return true;
  } on BlockFailure catch (failure) {
    if (context.mounted) context.showAppSnackBar(failure.message, isError: true);
    return false;
  }
}
