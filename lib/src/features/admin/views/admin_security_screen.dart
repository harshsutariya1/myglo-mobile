import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../shared/authentication/controllers/session_actions.dart';
import '../../shared/authentication/models/auth_repository.dart';
import '../controllers/admin_controllers.dart';
import 'widgets/admin_widgets.dart';

/// The signed-in admin's own account: two-factor and session.
class AdminSecurityScreen extends ConsumerWidget {
  const AdminSecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final status = ref.watch(adminStatusProvider).value;
    final email = ref.watch(supabaseClientProvider).auth.currentUser?.email;
    return Scaffold(
      appBar: AppBar(title: const Text('Your admin account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AdminSection(
            title: 'Account',
            children: [
              AdminInfoRow(label: 'Name', value: status?.displayName ?? '—'),
              AdminInfoRow(label: 'Email', value: email ?? '—'),
            ],
          ),
          AdminSection(
            title: 'Two-factor',
            children: [
              const AdminInfoRow(label: 'Authenticator', value: 'On (required for admins)', valueColor: AppTheme.success),
              AdminInfoRow(
                label: 'Last code',
                value: status?.totpVerifiedAt == null ? '—' : adminDateTime(status!.totpVerifiedAt!),
              ),
              AdminInfoRow(
                label: 'Session ends',
                value: status?.sessionExpiresAt == null ? '—' : adminDateTime(status!.sessionExpiresAt!),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Text(
                  'Sensitive changes ask for a new code. Lost your authenticator? Another admin '
                  'can reset it; see docs/admin.md.',
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => ref.read(sessionActionsProvider).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
