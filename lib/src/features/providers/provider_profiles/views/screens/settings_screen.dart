import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:restart_app/restart_app.dart';

import '../../../../../core/config/app_config.dart';
import '../../../../../core/routing/app_router.dart';
import '../../../../../core/services/shorebird_update_service.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/app_logger.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../../core/widgets/snackbar_utils.dart';
import '../../../../customers/provider_profile/views/widgets/section_states.dart';
import '../../../../shared/authentication/controllers/session_actions.dart';
import '../../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../../shared/notifications/push/push_notifications_controller.dart';
import '../../../../shared/notifications/push/push_settings.dart';
import '../../../../shared/bookings/models/booking_failure.dart';
import '../../../schedule/controllers/provider_schedule_controller.dart';
import '../../../schedule/views/widgets/booking_rules_section.dart';
import '../../controllers/provider_settings_controller.dart';
import '../widgets/settings_widgets.dart';

/// Provider settings hub: identity and status up top, then grouped settings.
///
/// Rows for features that aren't built yet are shown (so providers can see
/// what's coming) but marked "Soon" and only explain that when tapped.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final user = userAsync.value;
    final settings = ref.watch(ownBookingSettingsProvider).value;
    final profile = user?.profile;
    final address = profile?.addressText?.trim() ?? '';
    final located = profile?.coordinates != null && address.isNotEmpty;
    final covers = profile?.coverPhotos.length ?? 0;
    final email = user?.rawUser.email ?? profile?.email ?? '';
    final hasPhone = (profile?.phoneNumber?.trim() ?? '').isNotEmpty;
    void soon(String feature) => context.showComingSoon(feature);
    void editProfile() => context.pushNamed(AppRoute.editProviderProfile.name);

    final Widget body;
    if (user == null && userAsync.hasError) {
      body = Center(
        child: SingleChildScrollView(
          child: SectionErrorView(
            title: "Settings didn't load",
            message: describeLoadError(userAsync.error!, subject: 'your settings'),
            onRetry: () => ref.invalidate(userProfileProvider),
          ),
        ),
      );
    } else if (user == null) {
      body = const _SettingsSkeleton();
    } else {
      body = ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          _ProfileStatusCard(
            name: user.displayName,
            subtitle: user.displaySubtitle ?? email,
            avatarUrl: profile?.profilePic,
            onTap: editProfile,
            onVerification: () => soon('Provider verification'),
          ),
          SettingsSection(
            title: 'Business profile',
            children: [
              SettingsTile(
                icon: Icons.storefront_outlined,
                title: 'Public profile',
                subtitle: 'Photo, names, bio and phone number',
                onTap: editProfile,
              ),
              SettingsTile(
                icon: Icons.photo_library_outlined,
                title: 'Cover photos',
                subtitle: covers == 0
                    ? 'Add up to ${AppConfig.coverPhotosMax} photos of your space and work'
                    : '$covers of ${AppConfig.coverPhotosMax} photos',
                onTap: () => context.pushNamed(AppRoute.coverPhotos.name),
              ),
              SettingsTile(
                icon: Icons.place_outlined,
                title: 'Studio location',
                subtitle: located ? address : "Not set. Clients can't find you on the map yet",
                iconColor: located ? null : AppTheme.warning,
                onTap: () => context.pushNamed(AppRoute.businessLocation.name),
              ),
              SettingsTile(
                icon: Icons.radar_outlined,
                title: 'Where you work',
                subtitle: settings == null ? 'Studio and mobile appointments' : serviceAreaSummary(settings),
                onTap: () => context.pushNamed(AppRoute.serviceArea.name),
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
          const BookingRulesSection(),
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
            footer: 'Booking emails always go to $email.',
            children: [
              const _PushNotificationsTile(),
              SettingsTile(
                icon: Icons.sms_outlined,
                title: 'SMS alerts',
                soon: true,
                onTap: () => soon('SMS alerts'),
              ),
              SettingsTile(
                icon: Icons.mail_outline_rounded,
                title: 'Email preferences',
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
                available: hasPhone,
                onUnavailableTap: editProfile,
              ),
              SettingsTile(
                icon: Icons.alternate_email_rounded,
                title: 'Login email',
                subtitle: email.isEmpty ? null : email,
                soon: true,
                onTap: () => soon('Changing your login email'),
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
      );
    }

    return Scaffold(
      backgroundColor: settingsBackground(context),
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: settingsBackground(context),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0.5,
      ),
      body: body,
    );
  }
}

/// Placeholder while the profile loads.
class _SettingsSkeleton extends StatelessWidget {
  const _SettingsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        children: const [
          SkeletonBox(height: 160, borderRadius: 16),
          SizedBox(height: 32),
          SkeletonBox(height: 280, borderRadius: 16),
          SizedBox(height: 32),
          SkeletonBox(height: 220, borderRadius: 16),
        ],
      ),
    );
  }
}

/// Push notifications on/off for this phone. Android only for now; iOS
/// shows it as coming soon until APNs is configured.
class _PushNotificationsTile extends ConsumerStatefulWidget {
  const _PushNotificationsTile();

  @override
  ConsumerState<_PushNotificationsTile> createState() => _PushNotificationsTileState();
}

class _PushNotificationsTileState extends ConsumerState<_PushNotificationsTile> with PushToggleState {
  @override
  Widget build(BuildContext context) {
    final status = ref.watch(pushNotificationsProvider).value;
    final model = PushToggleModel.of(status);
    if (status == PushStatus.unsupported) {
      return SettingsTile(
        icon: Icons.notifications_none_rounded,
        title: 'Push notifications',
        subtitle: model.subtitle,
        soon: true,
        onTap: () => context.showComingSoon('Push notifications on this device'),
      );
    }
    final busy = pendingPushValue != null;
    final value = pendingPushValue ?? model.value;
    return SettingsTile(
      icon: Icons.notifications_active_outlined,
      title: 'Push notifications',
      subtitle: model.subtitle,
      iconColor: status == PushStatus.blocked ? AppTheme.warning : null,
      onTap: model.enabled && !busy ? () => setPush(!value) : null,
      trailing: Switch.adaptive(
        value: value,
        onChanged: model.enabled && !busy ? setPush : null,
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
  });

  final String name;
  final String subtitle;
  final String? avatarUrl;
  final VoidCallback onTap;
  final VoidCallback onVerification;

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
                            name.trim().isEmpty ? 'M' : name.trim().characters.first.toUpperCase(),
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
          const _AcceptingBookingsRow(),
        ],
      ),
    );
  }
}

/// Live switch for pausing new bookings. Existing appointments stay.
class _AcceptingBookingsRow extends ConsumerStatefulWidget {
  const _AcceptingBookingsRow();

  @override
  ConsumerState<_AcceptingBookingsRow> createState() => _AcceptingBookingsRowState();
}

class _AcceptingBookingsRowState extends ConsumerState<_AcceptingBookingsRow> {
  /// Optimistic value, held until the live settings show it (so the switch
  /// doesn't flick back while the change travels round).
  bool? _pending;
  bool _saving = false;
  Timer? _settle;

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  Future<void> _set(bool accepting) async {
    if (!accepting) {
      final pause = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Pause new bookings?'),
          content: const Text(
            "Clients won't be able to book you until you turn this back on. Your existing appointments "
            "aren't affected.",
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Pause')),
          ],
        ),
      );
      if (pause != true || !mounted) return;
    }
    _settle?.cancel();
    setState(() {
      _pending = accepting;
      _saving = true;
    });
    try {
      await ref.read(providerScheduleActionsProvider).updateSettings({'accepts_bookings': accepting});
      if (!mounted) return;
      context.showAppSnackBar(accepting ? "You're taking bookings again" : 'New bookings paused');
      // Fallback if the live update never arrives (e.g. realtime is down).
      _settle = Timer(const Duration(seconds: 8), () {
        if (mounted) setState(() => _pending = null);
      });
    } on BookingFailure catch (failure) {
      if (mounted) {
        setState(() => _pending = null);
        context.showAppSnackBar(failure.message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final settings = ref.watch(ownBookingSettingsProvider).value;
    if (_pending != null && !_saving && settings?.acceptsBookings == _pending) {
      _settle?.cancel();
      _pending = null;
    }
    final accepting = _pending ?? settings?.acceptsBookings ?? true;
    final enabled = settings != null && !_saving;

    return InkWell(
      onTap: enabled ? () => _set(!accepting) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accepting new clients',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface),
                  ),
                  const SizedBox(height: 6),
                  if (accepting)
                    const StatusPill(
                      label: 'Listed publicly',
                      color: AppTheme.success,
                      leading: PulsingDot(color: AppTheme.success, size: 7),
                    )
                  else
                    const StatusPill(label: 'Bookings paused', icon: Icons.pause_rounded, color: AppTheme.warning),
                ],
              ),
            ),
            Switch.adaptive(
              value: accepting,
              onChanged: enabled ? _set : null,
              activeTrackColor: AppTheme.success,
            ),
          ],
        ),
      ),
    );
  }
}

/// Live switch for showing an email address or phone number publicly.
class _ContactVisibilityTile extends ConsumerStatefulWidget {
  const _ContactVisibilityTile({
    required this.field,
    required this.value,
    required this.available,
    this.onUnavailableTap,
  });

  final ContactField field;
  final bool value;

  /// False when there's nothing to show (e.g. no phone number saved).
  final bool available;

  /// Where to add the missing detail.
  final VoidCallback? onUnavailableTap;

  @override
  ConsumerState<_ContactVisibilityTile> createState() => _ContactVisibilityTileState();
}

class _ContactVisibilityTileState extends ConsumerState<_ContactVisibilityTile> {
  /// Optimistic value, held until the refreshed profile shows it.
  bool? _pending;
  bool _saving = false;
  Timer? _settle;

  @override
  void didUpdateWidget(_ContactVisibilityTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pending != null && !_saving && widget.value == _pending) {
      _settle?.cancel();
      _pending = null;
    }
  }

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  Future<void> _set(bool visible) async {
    _settle?.cancel();
    setState(() {
      _pending = visible;
      _saving = true;
    });
    final ok = await ref.read(providerSettingsActionsProvider).setContactVisibility(widget.field, visible: visible);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!ok || widget.value == visible) _pending = null;
    });
    if (!ok) {
      context.showAppSnackBar("Couldn't update your privacy setting. Please try again.", isError: true);
    } else if (_pending != null) {
      _settle = Timer(const Duration(seconds: 8), () {
        if (mounted) setState(() => _pending = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmail = widget.field == ContactField.email;
    final value = _pending ?? widget.value;
    final enabled = widget.available && !_saving;
    return SettingsTile(
      icon: isEmail ? Icons.mail_outline_rounded : Icons.phone_outlined,
      title: isEmail ? 'Show email on profile' : 'Show phone on profile',
      subtitle: widget.available ? null : (isEmail ? 'No email on file' : 'Add a phone number to your profile first'),
      onTap: enabled ? () => _set(!value) : (widget.available ? null : widget.onUnavailableTap),
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

class _Footer extends ConsumerStatefulWidget {
  const _Footer({required this.onLegal});

  final ValueChanged<String> onLegal;

  @override
  ConsumerState<_Footer> createState() => _FooterState();
}

class _FooterState extends ConsumerState<_Footer> {
  bool _signingOut = false;

  Future<void> _confirmLogout() async {
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
    if (confirmed != true || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await ref.read(sessionActionsProvider).signOut();
      if (mounted) context.go(AppRoute.splash.path);
    } catch (e, st) {
      AppLogger.e('Sign out failed', tag: 'Settings', error: e, stackTrace: st);
      if (mounted) {
        setState(() => _signingOut = false);
        context.showAppSnackBar("Couldn't log you out. Please try again.", isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            TextButton(onPressed: () => widget.onLegal('Terms of service'), style: linkStyle, child: const Text('Terms')),
            Text('·', style: TextStyle(color: muted)),
            TextButton(onPressed: () => widget.onLegal('Privacy policy'), style: linkStyle, child: const Text('Privacy')),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _signingOut ? null : _confirmLogout,
          icon: _signingOut
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.logout_rounded, size: 18),
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
