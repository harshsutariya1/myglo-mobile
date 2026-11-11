import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/config/app_config.dart';
import '../../../../../core/config/remote_app_config.dart';
import '../../../../../core/platform/contact_launcher.dart';
import '../../../../../core/platform/system_bridge.dart';
import '../../../../../core/routing/app_router.dart';
import '../../../../../core/services/shorebird_update_service.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/app_logger.dart';
import '../../../../../core/utils/phone_numbers.dart';
import '../../../../../core/widgets/app_update_banner.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../../core/widgets/snackbar_utils.dart';
import '../../../../customers/provider_profile/views/widgets/section_states.dart';
import '../../../../shared/authentication/controllers/session_actions.dart';
import '../../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../../shared/authentication/models/profile_model.dart';
import '../../../../shared/notifications/push/push_notifications_controller.dart';
import '../../../../shared/notifications/push/push_settings.dart';
import '../../../../shared/bookings/models/booking_failure.dart';
import '../../../schedule/controllers/provider_schedule_controller.dart';
import '../../../schedule/views/widgets/booking_rules_section.dart';
import '../../../payments/views/widgets/payment_options_section.dart';
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
    // Off unless Myglo's platform settings allow it; the server enforces it.
    final canDeleteAccount = ref.watch(remoteAppConfigProvider).value?.providerSelfDeletion ?? false;
    final phoneVerified = profile?.isPhoneVerified ?? false;
    void verifyPhone() => context.pushNamed(AppRoute.verifyPhone.name);
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
            phoneVerified: phoneVerified,
            onVerification: verifyPhone,
          ),
          SettingsSection(
            title: 'Business profile',
            children: [
              SettingsTile(
                icon: Icons.storefront_outlined,
                title: 'Public profile',
                subtitle: 'Photo, names and bio',
                onTap: editProfile,
              ),
              SettingsTile(
                icon: Icons.phone_outlined,
                title: 'Phone number',
                subtitle: switch ((hasPhone, phoneVerified)) {
                  (_, true) => PhoneNumbers.display(profile?.phoneNumber),
                  (true, false) => '${PhoneNumbers.display(profile?.phoneNumber)} · not verified yet',
                  (false, false) => 'Add your mobile number and verify it',
                },
                iconColor: phoneVerified ? null : AppTheme.warning,
                badge: phoneVerified
                    ? const StatusPill(label: 'Verified', icon: Icons.verified_rounded, color: AppTheme.success)
                    : const StatusPill(label: 'Verify', color: AppTheme.warning),
                onTap: verifyPhone,
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
            ],
          ),
          const BookingRulesSection(),
          const PaymentOptionsSection(),
          SettingsSection(
            title: 'Payouts & banking',
            children: [
              SettingsTile(
                icon: Icons.account_balance_outlined,
                title: 'Card payments & payouts',
                subtitle: 'Set up with Stripe, bank details and payout history',
                onTap: () => context.pushNamed(AppRoute.providerPayments.name),
              ),
              SettingsTile(
                icon: Icons.calendar_month_outlined,
                title: 'Payout schedule',
                subtitle: 'Weekly, every Monday',
                onTap: () => context.pushNamed(AppRoute.providerPayments.name),
              ),
            ],
          ),
          SettingsSection(
            title: 'Notifications',
            footer: 'Booking emails always go to $email.',
            children: [
              const _PushNotificationsTile(),
            ],
          ),
          SettingsSection(
            title: 'Privacy & security',
            footer: canDeleteAccount
                ? 'Clients see your business phone number and email on your profile.'
                : 'Clients see your business phone number and email on your profile. '
                    'To close your account for good, email ${AppConfig.supportEmail}.',
            children: [
              const _MarketplaceVisibilityTile(),
              SettingsTile(
                icon: Icons.alternate_email_rounded,
                title: 'Login email',
                subtitle: email.isEmpty ? null : email,
                trailing: const SizedBox.shrink(),
              ),
              SettingsTile(
                icon: Icons.lock_outline_rounded,
                title: 'Change password',
                subtitle: email.isEmpty ? null : "We'll email you a code to confirm it's you",
                onTap: email.isEmpty
                    ? null
                    : () => context.pushNamed(AppRoute.resetPassword.name, queryParameters: {'email': email}),
              ),
              if (canDeleteAccount)
                SettingsTile(
                  icon: Icons.person_off_outlined,
                  title: 'Delete account',
                  subtitle: 'Close your business profile and payouts account',
                  iconColor: AppTheme.destructive,
                  onTap: () => context.pushNamed(AppRoute.deleteAccount.name),
                ),
            ],
          ),
          SettingsSection(
            title: 'Support & about',
            children: [
              const _ContactSupportTile(),
              const _AppUpdateTile(),
            ],
          ),
          const SizedBox(height: 28),
          const _Footer(),
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

/// Push notifications on/off for this phone (Android and iOS). Elsewhere
/// the switch stays off and disabled.
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
    final busy = pendingPushValue != null;
    final value = pendingPushValue ?? model.value;
    return SettingsTile(
      icon: status == PushStatus.unsupported ? Icons.notifications_off_outlined : Icons.notifications_active_outlined,
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
    required this.phoneVerified,
    required this.onVerification,
  });

  final String name;
  final String subtitle;
  final String? avatarUrl;
  final VoidCallback onTap;
  /// The business phone number has been confirmed by a texted code.
  final bool phoneVerified;
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
                        GestureDetector(
                          onTap: onVerification,
                          child: phoneVerified
                              ? const StatusPill(
                                  label: 'Phone verified',
                                  icon: Icons.verified_rounded,
                                  color: AppTheme.success,
                                )
                              : const StatusPill(
                                  label: 'Verify your phone',
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
                  if (settings?.hiddenFromMarketplace == true)
                    const StatusPill(
                      label: 'Hidden from marketplace',
                      icon: Icons.visibility_off_outlined,
                      color: AppTheme.warning,
                    )
                  else if (accepting)
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

/// Live switch that hides the business from the marketplace: the provider's
/// alternative to deleting their account. Hidden providers aren't shown to
/// clients and can't be booked (enforced by the server); their existing
/// bookings carry on.
class _MarketplaceVisibilityTile extends ConsumerStatefulWidget {
  const _MarketplaceVisibilityTile();

  @override
  ConsumerState<_MarketplaceVisibilityTile> createState() => _MarketplaceVisibilityTileState();
}

class _MarketplaceVisibilityTileState extends ConsumerState<_MarketplaceVisibilityTile> {
  /// Optimistic value, held until the live settings show it.
  bool? _pending;
  bool _saving = false;
  Timer? _settle;

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  Future<void> _set(bool hidden) async {
    if (hidden) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Hide your business?'),
          content: const Text(
            "Clients won't find you in search, on the map or in Discover, and nobody can make a new booking. "
            "Your profile, services and reviews are kept, and the appointments you already have aren't "
            'affected: you still need to turn up for them.\n\nYou can show your business again at any time.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Hide')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    _settle?.cancel();
    setState(() {
      _pending = hidden;
      _saving = true;
    });
    try {
      await ref.read(providerScheduleActionsProvider).updateSettings({'hidden_from_marketplace': hidden});
      if (!mounted) return;
      context.showAppSnackBar(hidden ? 'Your business is hidden' : 'Your business is back in the marketplace');
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
    final settings = ref.watch(ownBookingSettingsProvider).value;
    if (_pending != null && !_saving && settings?.hiddenFromMarketplace == _pending) {
      _settle?.cancel();
      _pending = null;
    }
    final hidden = _pending ?? settings?.hiddenFromMarketplace ?? false;
    final enabled = settings != null && !_saving;
    return SettingsTile(
      icon: hidden ? Icons.visibility_off_outlined : Icons.storefront_outlined,
      iconColor: hidden ? AppTheme.warning : null,
      title: 'Hide my business',
      subtitle: hidden
          ? "Hidden. Clients can't find or book you"
          : 'Stop appearing in the marketplace and taking new bookings',
      onTap: enabled ? () => _set(!hidden) : null,
      trailing: Switch.adaptive(value: hidden, onChanged: enabled ? _set : null),
    );
  }
}

/// Opens an email to Myglo's support address.
class _ContactSupportTile extends ConsumerWidget {
  const _ContactSupportTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsTile(
      icon: Icons.help_outline_rounded,
      title: 'Contact support',
      subtitle: AppConfig.supportEmail,
      onTap: () async {
        final opened = await ref.read(contactLauncherProvider).email(AppConfig.supportEmail);
        if (!opened && context.mounted) {
          context.showAppSnackBar('Email us at ${AppConfig.supportEmail}', isError: true);
        }
      },
    );
  }
}

/// Over-the-air patch status and manual update check. Runs the same flow as
/// the home screen's [AppUpdateBanner].
class _AppUpdateTile extends ConsumerWidget {
  const _AppUpdateTile();

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    final service = ref.read(shorebirdUpdateServiceProvider.notifier);
    final phase = ref.read(shorebirdUpdateServiceProvider).phase;
    if (phase == ShorebirdUpdatePhase.readyToRestart) {
      await restartIntoUpdate(context, ref);
      return;
    }
    if (!service.isAvailable) {
      context.showAppSnackBar("You're on the latest version");
      return;
    }
    // A check downloads any patch it finds; after a failed download, retry it.
    final ShorebirdUpdateState result;
    if (phase == ShorebirdUpdatePhase.available) {
      await service.downloadUpdate();
      result = ref.read(shorebirdUpdateServiceProvider);
    } else {
      result = await service.checkForUpdate(force: true);
    }
    if (!context.mounted) return;
    switch (result.phase) {
      case ShorebirdUpdatePhase.readyToRestart:
        context.showAppSnackBar('Update downloaded. Tap "Restart to update" to finish.');
      case ShorebirdUpdatePhase.available:
        context.showAppSnackBar("Couldn't download the update. Please try again.", isError: true);
      case ShorebirdUpdatePhase.idle || ShorebirdUpdatePhase.downloading || ShorebirdUpdatePhase.restarting:
        context.showAppSnackBar("You're on the latest version");
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shorebirdUpdateServiceProvider);
    final patch = state.currentPatch;

    return SettingsTile(
      icon: Icons.system_update_outlined,
      title: switch (state.phase) {
        ShorebirdUpdatePhase.readyToRestart || ShorebirdUpdatePhase.restarting => 'Restart to update',
        ShorebirdUpdatePhase.available => 'Download update',
        ShorebirdUpdatePhase.downloading => 'Downloading update',
        ShorebirdUpdatePhase.idle => 'Check for updates',
      },
      subtitle: switch (state.phase) {
        ShorebirdUpdatePhase.downloading => 'Downloading…',
        ShorebirdUpdatePhase.restarting => 'Restarting…',
        _ when state.isChecking => 'Checking…',
        _ => patch == null ? 'No patches installed' : 'Current patch: $patch',
      },
      onTap: state.isBusy ? null : () => _onTap(context, ref),
      badge: switch (state.phase) {
        ShorebirdUpdatePhase.readyToRestart => const StatusPill(label: 'Ready', color: AppTheme.success),
        ShorebirdUpdatePhase.available => const StatusPill(label: 'New', color: AppTheme.warning),
        _ => null,
      },
      trailing: state.isBusy
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
    );
  }
}

class _Footer extends ConsumerStatefulWidget {
  const _Footer();

  @override
  ConsumerState<_Footer> createState() => _FooterState();
}

class _FooterState extends ConsumerState<_Footer> {
  bool _signingOut = false;

  /// Opens the Terms or Privacy Policy page in the browser.
  Future<void> _openLegal(Uri url) async {
    final opened = await ref.read(systemBridgeProvider).openUrl(url);
    if (!opened && mounted) {
      context.showAppSnackBar("Couldn't open the page. You can read it at ${url.host}${url.path}.", isError: true);
    }
  }

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
    final patch = ref.watch(shorebirdUpdateServiceProvider).currentPatch;
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
            TextButton(onPressed: () => _openLegal(AppConfig.termsUrl), style: linkStyle, child: const Text('Terms')),
            Text('·', style: TextStyle(color: muted)),
            TextButton(onPressed: () => _openLegal(AppConfig.privacyUrl), style: linkStyle, child: const Text('Privacy')),
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
