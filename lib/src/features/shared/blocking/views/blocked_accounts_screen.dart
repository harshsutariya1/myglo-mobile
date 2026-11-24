import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../../customers/provider_profile/views/widgets/section_states.dart';
import '../../bookings/views/widgets/booking_card.dart' show PersonAvatar;
import '../controllers/blocks_controller.dart';
import '../models/blocked_user.dart';
import '../models/blocks_repository.dart';

/// The accounts the user has blocked, each with "Unblock". Reached from
/// client Account Settings and provider Settings.
class BlockedAccountsScreen extends ConsumerWidget {
  const BlockedAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(blockedUsersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked accounts')),
      body: switch (async) {
        AsyncData(value: final users) when users.isEmpty => const Center(
            child: SingleChildScrollView(
              child: SectionEmptyView(
                icon: Icons.block_rounded,
                title: 'Nobody blocked',
                message: 'Block someone from their profile, a post or a comment. They appear here, and you can '
                    'unblock them at any time.',
              ),
            ),
          ),
        AsyncData(value: final users) => ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) => _BlockedTile(user: users[index]),
          ),
        AsyncError(:final error) => Center(
            child: SingleChildScrollView(
              child: SectionErrorView(
                title: "Blocked accounts didn't load",
                message: describeLoadError(error, subject: 'your blocked accounts'),
                onRetry: () => ref.invalidate(blockedUsersProvider),
              ),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _BlockedTile extends ConsumerStatefulWidget {
  const _BlockedTile({required this.user});

  final BlockedUser user;

  @override
  ConsumerState<_BlockedTile> createState() => _BlockedTileState();
}

class _BlockedTileState extends ConsumerState<_BlockedTile> {
  bool _busy = false;

  Future<void> _unblock() async {
    final user = widget.user;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Unblock ${user.displayName}?'),
        content: const Text(
          "You'll see each other's posts and comments again and can book together. "
          "Follows that ended when you blocked them don't come back.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Unblock')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(blockActionsProvider).unblock(user.userId);
      if (mounted) context.showAppSnackBar('${user.displayName} is unblocked');
    } on BlockFailure catch (failure) {
      if (mounted) context.showAppSnackBar(failure.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: PersonAvatar(name: user.displayName, url: user.avatarUrl, size: 44),
      title: Text(user.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${user.isProvider ? 'Provider' : 'Client'} · blocked ${Formatters.dateShort(user.blockedAt.toLocal())}',
      ),
      trailing: OutlinedButton(
        onPressed: _busy ? null : _unblock,
        child: _busy
            ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Unblock'),
      ),
    );
  }
}
