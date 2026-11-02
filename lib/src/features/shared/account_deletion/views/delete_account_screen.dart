import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../../customers/provider_profile/views/widgets/section_states.dart';
import '../../authentication/controllers/session_actions.dart';
import '../controllers/account_deletion_controller.dart';
import '../models/account_deletion_repository.dart';
import '../models/account_deletion_status.dart';

/// Settings → Delete account, for clients and providers. Says what goes and
/// what's kept, lists anything that has to be sorted first, then asks for
/// the password before deleting.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _passwordError;

  /// Blockers the server reported on delete that the status doesn't cover
  /// (e.g. money still in a provider's Stripe balance).
  List<AccountDeletionBlocker> _serverBlockers = const [];

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    FocusScope.of(context).unfocus();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text("This can't be undone. Your profile and everything in it will be gone."),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.destructive, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _passwordError = null;
    });
    final repository = ref.read(accountDeletionRepositoryProvider);
    try {
      await repository.confirmPassword(_password.text);
      await repository.deleteAccount();
    } on AccountDeletionFailure catch (failure) {
      if (!mounted) return;
      setState(() => _busy = false);
      switch (failure.code) {
        case AccountDeletionFailureCode.wrongPassword:
        case AccountDeletionFailureCode.reauthRequired:
          setState(() => _passwordError = failure.message);
        case AccountDeletionFailureCode.blocked:
          // Something changed since the screen loaded: show what's in the way.
          setState(() => _serverBlockers = failure.blockers);
          ref.invalidate(accountDeletionStatusProvider);
          context.showAppSnackBar(failure.message, isError: true);
        default:
          context.showAppSnackBar(failure.message, isError: true);
      }
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Account deleted'),
        content: const Text("Your Myglo account has been deleted. We'll send a confirmation to your email."),
        actions: [
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('OK')),
        ],
      ),
    );
    try {
      await ref.read(sessionActionsProvider).signOutAfterAccountDeletion();
    } catch (e, st) {
      AppLogger.e('Sign-out after account deletion failed', tag: 'AccountDeletion', error: e, stackTrace: st);
    }
    if (mounted) context.go(AppRoute.splash.path);
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(accountDeletionStatusProvider);
    final status = statusAsync.value;

    final Widget body;
    if (status == null && statusAsync.hasError) {
      body = Center(
        child: SingleChildScrollView(
          child: SectionErrorView(
            title: "This didn't load",
            message: describeLoadError(statusAsync.error!, subject: 'your account details'),
            onRetry: () => ref.invalidate(accountDeletionStatusProvider),
          ),
        ),
      );
    } else if (status == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = _DeleteAccountBody(
        status: status.blockers.isEmpty && _serverBlockers.isNotEmpty ? status.copyWith(blockers: _serverBlockers) : status,
        password: _password,
        obscure: _obscure,
        busy: _busy,
        passwordError: _passwordError,
        onToggleObscure: () => setState(() => _obscure = !_obscure),
        onDelete: _delete,
      );
    }

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: context.colorScheme.surface,
        appBar: AppBar(
          title: const Text('Delete account'),
          backgroundColor: context.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0.5,
        ),
        body: body,
      ),
    );
  }
}

class _DeleteAccountBody extends StatelessWidget {
  const _DeleteAccountBody({
    required this.status,
    required this.password,
    required this.obscure,
    required this.busy,
    required this.passwordError,
    required this.onToggleObscure,
    required this.onDelete,
  });

  final AccountDeletionStatus status;
  final TextEditingController password;
  final bool obscure;
  final bool busy;
  final String? passwordError;
  final VoidCallback onToggleObscure;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.65);
    final provider = status.isProvider;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + MediaQuery.paddingOf(context).bottom),
      children: [
        Text(
          'Deleting your account is permanent',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface),
        ),
        const SizedBox(height: 8),
        Text(
          "You can sign up again with the same email later, but nothing from this account comes back.",
          style: TextStyle(fontSize: 14.5, height: 1.4, color: muted),
        ),
        _Section(
          title: "What's deleted",
          points: [
            if (provider) ...[
              'Your business profile, services, photos and schedule. You stop appearing in search.',
              'Your posts, reviews and rating.',
            ] else ...[
              'Your profile, photo and contact details.',
              'Your favourites, posts, comments, likes and reviews.',
            ],
            'Your notifications and sign-in.',
            if (status.hasPayoutAccount)
              'Your Stripe payouts account is closed. Stripe keeps its own records as the law requires.',
          ],
        ),
        _Section(
          title: 'What we keep',
          points: [
            'Records of past bookings and payments, which we must keep for tax and legal reasons. '
                'Your name, phone number and address are removed from them.',
            if (provider) "Your business name stays on clients' receipts for bookings they've already had.",
          ],
        ),
        if (!status.canDelete) ...[
          const SizedBox(height: 24),
          Text(
            'Before you can delete',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurface),
          ),
          const SizedBox(height: 10),
          for (final blocker in status.blockers) _BlockerCard(blocker: blocker),
        ] else ...[
          const SizedBox(height: 28),
          TextField(
            key: const ValueKey('delete-account-password'),
            controller: password,
            enabled: !busy,
            obscureText: obscure,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Password',
              helperText: 'Enter your password to confirm.',
              errorText: passwordError,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: obscure ? 'Show password' : 'Hide password',
                onPressed: onToggleObscure,
                icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
            onSubmitted: (_) {
              if (password.text.isNotEmpty && !busy) onDelete();
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('delete-account-button'),
            onPressed: password.text.isEmpty || busy ? null : onDelete,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.destructive,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            child: busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text('Delete my account'),
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.points});

  final String title;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurface)),
          const SizedBox(height: 8),
          for (final point in points)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(color: scheme.onSurface.withValues(alpha: 0.5), shape: BoxShape.circle),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(fontSize: 14.5, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.8)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BlockerCard extends StatelessWidget {
  const _BlockerCard({required this.blocker});

  final AccountDeletionBlocker blocker;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(blocker.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface)),
                const SizedBox(height: 4),
                Text(
                  blocker.message,
                  style: TextStyle(fontSize: 14, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
