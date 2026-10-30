import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/widgets/snackbar_utils.dart';
import '../../shared/authentication/controllers/session_actions.dart';
import '../../shared/authentication/models/auth_repository.dart';
import '../controllers/admin_controllers.dart';
import '../models/admin_mfa.dart';
import 'widgets/totp_code_form.dart';

/// Two-factor for admin accounts, shown after signing in: sets up an
/// authenticator the first time, then asks for a code every session. The
/// router sends admins here until their session is aal2, and the server
/// refuses every admin call until then.
class AdminVerifyScreen extends ConsumerStatefulWidget {
  const AdminVerifyScreen({super.key});

  @override
  ConsumerState<AdminVerifyScreen> createState() => _AdminVerifyScreenState();
}

class _AdminVerifyScreenState extends ConsumerState<AdminVerifyScreen> {
  TotpEnrollment? _enrollment;
  bool _starting = false;

  Future<void> _startEnrollment() async {
    setState(() => _starting = true);
    try {
      final enrollment = await ref.read(adminMfaProvider).enroll();
      if (mounted) setState(() => _enrollment = enrollment);
    } catch (e, st) {
      AppLogger.e('Starting authenticator set-up failed', tag: 'AdminMfa', error: e, stackTrace: st);
      if (mounted) context.showAppSnackBar("Couldn't start set-up. Please try again.", isError: true);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _openAuthenticator(TotpEnrollment enrollment) async {
    final opened = await launchUrl(Uri.parse(enrollment.uri), mode: LaunchMode.externalApplication)
        .catchError((Object _) => false);
    if (!opened && mounted) {
      context.showAppSnackBar('No authenticator app found. Copy the setup key into one instead.', isError: true);
    }
  }

  Future<void> _copyKey(TotpEnrollment enrollment) async {
    await Clipboard.setData(ClipboardData(text: enrollment.secret));
    if (mounted) context.showAppSnackBar('Setup key copied');
  }

  void _verified() {
    ref.invalidate(adminMfaStateProvider);
    ref.invalidate(adminStatusProvider);
    unawaited(_refreshSession());
  }

  /// The session is now aal2 and the router moves on when the auth state
  /// updates; refreshing makes sure that happens straight away.
  Future<void> _refreshSession() async {
    try {
      await ref.read(supabaseClientProvider).auth.refreshSession();
    } catch (e, st) {
      AppLogger.w('Refreshing the session after two-factor failed', tag: 'AdminMfa', error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final mfa = ref.watch(adminMfaStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin sign-in'),
        actions: [
          TextButton(
            onPressed: () => ref.read(sessionActionsProvider).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                Icon(Icons.admin_panel_settings_outlined, size: 64, color: scheme.secondary),
                const SizedBox(height: 16),
                switch (mfa) {
                  AsyncData(:final value) when value.isEnrolled => _VerifyStep(
                      factorId: value.verifiedFactorId!,
                      onVerified: _verified,
                    ),
                  AsyncData() => _enrollment == null
                      ? _IntroStep(busy: _starting, onStart: _startEnrollment)
                      : _EnrollStep(
                          enrollment: _enrollment!,
                          onOpen: () => _openAuthenticator(_enrollment!),
                          onCopy: () => _copyKey(_enrollment!),
                          onVerified: _verified,
                        ),
                  AsyncError() => Column(
                      children: [
                        const Text("Couldn't check your two-factor set-up.", textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => ref.invalidate(adminMfaStateProvider),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  _ => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scheme.onSurface),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.65)),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _IntroStep extends StatelessWidget {
  const _IntroStep({required this.busy, required this.onStart});

  final bool busy;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Heading(
          title: 'Set up two-factor',
          body: 'Admin accounts need an authenticator app (such as Google Authenticator, 1Password or '
              'Microsoft Authenticator). You will enter a code from it every time you sign in and before '
              'sensitive changes.',
        ),
        FilledButton(
          onPressed: busy ? null : onStart,
          child: busy
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
              : const Text('Set up authenticator'),
        ),
      ],
    );
  }
}

class _EnrollStep extends StatelessWidget {
  const _EnrollStep({required this.enrollment, required this.onOpen, required this.onCopy, required this.onVerified});

  final TotpEnrollment enrollment;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback onVerified;

  /// The secret in groups of four, easier to type.
  String get _groupedSecret => enrollment.secret
      .replaceAllMapped(RegExp(r'.{4}'), (m) => '${m.group(0)} ')
      .trim();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Heading(
          title: 'Add Myglo Admin to your authenticator',
          body: 'Open it in your authenticator app, or copy the setup key into it. Then enter the code it shows.',
        ),
        FilledButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Open in authenticator app'),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  _groupedSecret,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 15, letterSpacing: 1, color: scheme.onSurface),
                ),
              ),
              IconButton(onPressed: onCopy, icon: const Icon(Icons.copy_rounded), tooltip: 'Copy setup key'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Keep this key private. Anyone with it can generate your codes.",
          style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.55)),
        ),
        const SizedBox(height: 28),
        TotpCodeForm(factorId: enrollment.factorId, onVerified: onVerified, autofocus: false),
      ],
    );
  }
}

class _VerifyStep extends StatelessWidget {
  const _VerifyStep({required this.factorId, required this.onVerified});

  final String factorId;
  final VoidCallback onVerified;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      children: [
        const _Heading(
          title: 'Enter your authenticator code',
          body: 'Admin access needs a code from your authenticator app each session.',
        ),
        TotpCodeForm(factorId: factorId, onVerified: onVerified),
        const SizedBox(height: 24),
        Text(
          'Lost your authenticator? Another admin can reset it for you.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.55)),
        ),
      ],
    );
  }
}
