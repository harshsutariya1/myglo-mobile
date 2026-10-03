import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:restart_app/restart_app.dart';

import '../../../../../core/routing/app_router.dart';
import '../../../../../core/services/shorebird_update_service.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/app_logger.dart';
import '../../../../../core/widgets/snackbar_utils.dart';
import '../../../../../core/widgets/soon_badge.dart';
import '../../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../../shared/authentication/models/auth_repository.dart';
import '../../controllers/provider_settings_controller.dart';
import '../widgets/settings_widgets.dart';
import 'edit_provider_profile_screen.dart';

/// Provider settings hub: identity and status up top, then grouped settings.
///
/// Rows for features that aren't built yet are shown (so providers can see
/// what's coming) but marked "Soon" and only explain that when tapped.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _openEditProfile(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProviderProfileScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value;
    final profile = user?.profile;
    final address = profile?.addressText?.trim() ?? '';
    final email = user?.rawUser.email ?? profile?.email ?? '';
    void soon(String feature) => context.showComingSoon(feature);

    return Scaffold(
      backgroundColor: settingsBackground(context),
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: settingsBackground(context),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.5,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          if (user != null)
            _ProfileStatusCard(
              name: user.displayName,
              subtitle: user.displaySubtitle ?? email,
              avatarUrl: profile?.profilePic,
              onTap: () => _openEditProfile(context),
              onVerification: () => soon('Provider verification'),
              onAcceptingToggle: () => soon('Pausing new bookings'),
            ),
          SettingsSection(
            title: 'Account & profile',
            children: [
              SettingsTile(
                icon: Icons.storefront_outlined,
                title: 'Public profile',
                subtitle: 'Photo, business name, bio and contact details',
                onTap: () => _openEditProfile(context),
              ),
              SettingsTile(
                icon: Icons.badge_outlined,
                title: 'Account details',
                subtitle: 'Your name and phone number',
                onTap: () => context.pushNamed(AppRoute.accountDetails.name),
              ),
              SettingsTile(
                icon: Icons.alternate_email_rounded,
                title: 'Login email',
                subtitle: email.isEmpty ? null : email,
                soon: true,
                onTap: () => soon('Changing your login email'),
              ),
            ],
          ),
          SettingsSection(
            title: 'Business details',
            children: [
              SettingsTile(
                icon: Icons.place_outlined,
                title: 'Business address',
                subtitle: address.isEmpty ? 'Not set' : address,
                onTap: () => _openEditProfile(context),
              ),
              SettingsTile(
                icon: Icons.radar_outlined,
                title: 'Service area',
                subtitle: 'How far you travel for mobile appointments',
                soon: true,
                onTap: () => soon('Service areas'),
              ),
              SettingsTile(
                icon: Icons.receipt_long_outlined,
                title: 'ABN & GST',
                subtitle: 'Australian Business Number and GST registration',
                soon: true,
                onTap: () => soon('ABN details'),
              ),
              SettingsTile(
                icon: Icons.link_rounded,
                title: 'Portfolio & social links',
                soon: true,
                onTap: () => soon('Portfolio links'),
              ),
            ],
          ),
          SettingsSection(
            title: 'Availability & bookings',
            footer: 'Times are in Gold Coast time (AEST, UTC+10). Queensland has no daylight saving.',
            children: [
              SettingsTile(
                icon: Icons.schedule_rounded,
                title: 'Working hours',
                soon: true,
                onTap: () => soon('Working hours'),
              ),
              SettingsTile(
                icon: Icons.more_time_rounded,
                title: 'Buffer between bookings',
                soon: true,
                onTap: () => soon('Booking buffers'),
              ),
              SettingsTile(
                icon: Icons.notification_important_outlined,
                title: 'Minimum notice',
                subtitle: 'How far ahead clients must book',
                soon: true,
                onTap: () => soon('Minimum notice'),
              ),
              SettingsTile(
                icon: Icons.event_busy_outlined,
                title: 'Cancellation policy',
                soon: true,
                onTap: () => soon('Cancellation policies'),
              ),
            ],
          ),
          SettingsSection(
            title: 'Payouts & banking',
            children: [
              SettingsTile(
                icon: Icons.account_balance_outlined,
                title: 'Bank account',
                subtitle: 'BSB and account number for payouts',
                soon: true,
                onTap: () => soon('Payouts'),
              ),
              SettingsTile(
                icon: Icons.calendar_month_outlined,
                title: 'Payout schedule',
                soon: true,
                onTap: () => soon('Payout schedules'),
              ),
              SettingsTile(
                icon: Icons.request_quote_outlined,
                title: 'Invoices & tax receipts',
                soon: true,
                onTap: () => soon('Automated invoices'),
              ),
            ],
          ),
          SettingsSection(
            title: 'Notifications',
            children: [
              SettingsTile(
                icon: Icons.notifications_none_rounded,
                title: 'Push notifications',
                soon: true,
                onTap: () => soon('Notification settings'),
              ),
              SettingsTile(
                icon: Icons.sms_outlined,
                title: 'SMS alerts',
                soon: true,
                onTap: () => soon('SMS alerts'),
              ),
              SettingsTile(
                icon: Icons.mail_outline_rounded,
                title: 'Email updates',
                soon: true,
                onTap: () => soon('Email preferences'),
              ),
            ],
          ),
          SettingsSection(
            title: 'Privacy & security',
            footer: 'Hidden details stay private. Clients can still book through Myglo.',
            children: [
              _ContactVisibilityTile(
                field: ContactField.email,
                value: profile?.isEmailPublic ?? false,
                available: email.isNotEmpty,
              ),
              _ContactVisibilityTile(
                field: ContactField.phone,
                value: profile?.isPhonePublic ?? false,
                available: (profile?.phoneNumber?.trim() ?? '').isNotEmpty,
              ),
              SettingsTile(
                icon: Icons.verified_user_outlined,
                title: 'Two-step verification',
                soon: true,
                onTap: () => soon('Two-step verification'),
              ),
              SettingsTile(
                icon: Icons.fingerprint_rounded,
                title: 'Face ID & fingerprint login',
                soon: true,
                onTap: () => soon('Biometric login'),
              ),
            ],
          ),
          SettingsSection(
            title: 'Support & about',
            children: [
              SettingsTile(
                icon: Icons.help_outline_rounded,
                title: 'Help centre',
                soon: true,
                onTap: () => soon('The help centre'),
              ),
              const _AppUpdateTile(),
            ],
          ),
          const SizedBox(height: 28),
          _Footer(onLegal: soon),
        ],
      ),
    );
  }
}

/// Avatar, name, verification state and booking availability.
class _ProfileStatusCard extends StatelessWidget {
  const _ProfileStatusCard({
    required this.name,
    required this.subtitle,
    required this.avatarUrl,
    required this.onTap,
    required this.onVerification,
    required this.onAcceptingToggle,
  });

  final String name;
  final String subtitle;
  final String? avatarUrl;
  final VoidCallback onTap;
  final VoidCallback onVerification;
  final VoidCallback onAcceptingToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.55);
    final url = avatarUrl;

    return SettingsCard(
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: scheme.primary,
                    backgroundImage: url != null ? CachedNetworkImageProvider(url) : null,
                    child: url == null
                        ? Text(
                            name.characters.first.toUpperCase(),
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: scheme.onPrimary),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: scheme.onSurface),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: muted)),
                        ],
                        const SizedBox(height: 8),
                        // Verification isn't built yet, so nobody is verified.
                        GestureDetector(
                          onTap: onVerification,
                          child: const StatusPill(
                            label: 'Unverified',
                            icon: Icons.error_outline_rounded,
                            color: AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withValues(alpha: 0.3)),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: scheme.onSurface.withValues(alpha: 0.06)),
          InkWell(
            onTap: onAcceptingToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Accepting new clients',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface),
                            ),
                            const SizedBox(width: 8),
                            const SoonBadge(),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Every provider profile is publicly listed today.
                        const StatusPill(
                          label: 'Listed publicly',
                          color: AppTheme.success,
                          leading: PulsingDot(color: AppTheme.success, size: 7),
                        ),
                      ],
                    ),
                  ),
                  IgnorePointer(
                    child: Switch(value: true, onChanged: null, activeTrackColor: AppTheme.success),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live switch for showing an email address or phone number publicly.
class _ContactVisibilityTile extends ConsumerStatefulWidget {
  const _ContactVisibilityTile({required this.field, required this.value, required this.available});

  final ContactField field;
  final bool value;

  /// False when there's nothing to show (e.g. no phone number saved).
  final bool available;

  @override
  ConsumerState<_ContactVisibilityTile> createState() => _ContactVisibilityTileState();
}

class _ContactVisibilityTileState extends ConsumerState<_ContactVisibilityTile> {
  /// Optimistic value while a save is in flight.
  bool? _pending;

  Future<void> _set(bool visible) async {
    setState(() => _pending = visible);
    final ok = await ref.read(providerSettingsActionsProvider).setContactVisibility(widget.field, visible: visible);
    if (!mounted) return;
    setState(() => _pending = null);
    if (!ok) context.showAppSnackBar("Couldn't update your privacy setting. Please try again.", isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final isEmail = widget.field == ContactField.email;
    final value = _pending ?? widget.value;
    final saving = _pending != null;
    final enabled = widget.available && !saving;
    return SettingsTile(
      icon: isEmail ? Icons.mail_outline_rounded : Icons.phone_outlined,
      title: isEmail ? 'Show email on profile' : 'Show phone on profile',
      subtitle: widget.available ? null : (isEmail ? 'No email on file' : 'Add a phone number in Account details first'),
      onTap: enabled ? () => _set(!value) : null,
      trailing: Switch.adaptive(
        value: value && widget.available,
        onChanged: enabled ? _set : null,
      ),
    );
  }
}

/// Over-the-air patch status and manual update check.
class _AppUpdateTile extends ConsumerWidget {
  const _AppUpdateTile();

  Future<void> _check(BuildContext context, WidgetRef ref) async {
    final service = ref.read(shorebirdUpdateServiceProvider.notifier);
    final bool isAvailable;
    try {
      isAvailable = await service.checkForUpdate();
    } catch (e, st) {
      AppLogger.e('Update check failed', tag: 'Settings', error: e, stackTrace: st);
      if (context.mounted) context.showAppSnackBar("Couldn't check for updates. Please try again.", isError: true);
      return;
    }
    if (!context.mounted) return;
    if (!isAvailable) {
      context.showAppSnackBar("You're on the latest version");
      return;
    }
    final download = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update available'),
        content: const Text('A new update is ready. Download it now?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Later')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Download')),
        ],
      ),
    );
    if (download != true) return;
    try {
      await service.downloadUpdate();
      if (context.mounted) context.showAppSnackBar('Update downloaded. Tap "Restart to update" to finish.');
    } catch (e, st) {
      AppLogger.e('Update download failed', tag: 'Settings', error: e, stackTrace: st);
      if (context.mounted) context.showAppSnackBar("Couldn't download the update. Please try again.", isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shorebirdUpdateServiceProvider);
    final busy = state.isChecking || state.isDownloading;
    final ready = state.isUpdateReadyToInstall;
    final patch = state.currentPatchVersion;

    return SettingsTile(
      icon: Icons.system_update_outlined,
      title: ready ? 'Restart to update' : 'Check for updates',
      subtitle: busy
          ? (state.isDownloading ? 'Downloading…' : 'Checking…')
          : patch == null
              ? 'No patches installed'
              : 'Current patch: $patch',
      onTap: busy ? null : (ready ? Restart.restartApp : () => _check(context, ref)),
      badge: ready ? const StatusPill(label: 'Ready', color: AppTheme.success) : null,
      trailing: busy
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.onLegal});

  final ValueChanged<String> onLegal;

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You'll need to sign in again to manage your bookings and profile."),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.destructive, foregroundColor: Colors.white),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authRepositoryProvider).signOut();
      if (context.mounted) context.go(AppRoute.splash.path);
    } catch (e, st) {
      AppLogger.e('Sign out failed', tag: 'Settings', error: e, stackTrace: st);
      if (context.mounted) context.showAppSnackBar("Couldn't log you out. Please try again.", isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.45);
    final patch = ref.watch(shorebirdUpdateServiceProvider).currentPatchVersion;
    final linkStyle = TextButton.styleFrom(
      foregroundColor: muted,
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      visualDensity: VisualDensity.compact,
    );

    return Column(
      children: [
        Text(patch == null ? 'Myglo' : 'Myglo · patch $patch', style: TextStyle(fontSize: 12.5, color: muted)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(onPressed: () => onLegal('Terms of service'), style: linkStyle, child: const Text('Terms')),
            Text('·', style: TextStyle(color: muted)),
            TextButton(onPressed: () => onLegal('Privacy policy'), style: linkStyle, child: const Text('Privacy')),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _confirmLogout(context, ref),
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Log out'),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.destructive,
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }
}
