import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/snackbar_utils.dart';
import '../models/admin_failure.dart';
import '../views/widgets/totp_code_form.dart';
import 'admin_controllers.dart';

/// Whether the admin area is locked behind an authenticator code: after
/// [AppConfig.adminIdleLock] without use, or when the server says the admin
/// session needs two-factor again.
final adminLockProvider = NotifierProvider<AdminLock, bool>(AdminLock.new);

class AdminLock extends Notifier<bool> {
  @override
  bool build() => false;

  void lock() => state = true;

  void unlock() => state = false;
}

/// Asks the admin for a fresh authenticator code. Returns true once it's
/// verified (the session then has a new two-factor time the server accepts
/// for sensitive changes), false if they close the sheet.
Future<bool> confirmWithAuthenticator(
  BuildContext context, {
  String title = "Confirm it's you",
  String message = 'Enter a code from your authenticator app to make this change.',
}) async {
  final verified = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (sheetContext) => _ConfirmSheet(title: title, message: message),
  );
  return verified ?? false;
}

class _ConfirmSheet extends ConsumerWidget {
  const _ConfirmSheet({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final mfa = ref.watch(adminMfaStateProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_outlined, size: 40, color: scheme.secondary),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface)),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.65)),
          ),
          const SizedBox(height: 20),
          switch (mfa) {
            AsyncData(:final value) when value.verifiedFactorId != null => TotpCodeForm(
                factorId: value.verifiedFactorId!,
                onVerified: () {
                  ref.invalidate(adminMfaStateProvider);
                  Navigator.of(context).pop(true);
                },
              ),
            AsyncError() => TextButton(
                onPressed: () => ref.invalidate(adminMfaStateProvider),
                child: const Text("Couldn't load your authenticator. Try again"),
              ),
            _ => const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
          },
        ],
      ),
    );
  }
}

/// Runs an admin action and handles what the server can say about it:
///
/// * [sensitive] actions ask for an authenticator code first (the server
///   requires one from the last few minutes and would refuse otherwise);
/// * `reauth_required` asks for a code and retries once;
/// * an expired or unverified admin session locks the admin area;
/// * any other refusal is shown as a snackbar.
///
/// Returns the action's result, or null if it didn't happen.
Future<T?> runAdminAction<T>(
  BuildContext context,
  WidgetRef ref, {
  required Future<T> Function() action,
  bool sensitive = false,
  String? confirmMessage,
  String? successMessage,
}) async {
  if (sensitive) {
    final ok = await confirmWithAuthenticator(
      context,
      message: confirmMessage ?? 'Enter a code from your authenticator app to make this change.',
    );
    if (!ok || !context.mounted) return null;
  }

  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      final result = await action();
      if (successMessage != null && context.mounted) context.showAppSnackBar(successMessage);
      return result;
    } catch (e) {
      final failure = AdminFailure.from(e);
      if (!context.mounted) return null;
      if (failure.code == AdminFailureCode.reauthRequired && attempt == 0) {
        final ok = await confirmWithAuthenticator(context, message: failure.message);
        if (!ok || !context.mounted) return null;
        continue;
      }
      if (failure.needsVerification) {
        ref.read(adminLockProvider.notifier).lock();
      } else {
        context.showAppSnackBar(failure.message, isError: true);
      }
      return null;
    }
  }
  return null;
}
