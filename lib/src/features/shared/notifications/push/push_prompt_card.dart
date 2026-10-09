import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_logger.dart';
import '../../authentication/controllers/user_profile_provider.dart';
import 'push_notifications_controller.dart';

/// Asks for notification permission where it obviously helps (a provider's
/// bookings, a client waiting on a reply) instead of on launch.
///
/// Only shows while pushes are off or blocked. Dismissing it hides it for
/// [snooze] on this device.
class PushPromptCard extends ConsumerStatefulWidget {
  const PushPromptCard({
    super.key,
    required this.placement,
    required this.title,
    required this.message,
    this.margin = EdgeInsets.zero,
  });

  /// For a provider's home: they need to hear about new requests.
  const PushPromptCard.provider({Key? key, EdgeInsets margin = EdgeInsets.zero})
      : this(
          key: key,
          placement: 'provider_home',
          title: 'Never miss a booking request',
          message: 'Get a notification the moment a client books or asks for a time.',
          margin: margin,
        );

  /// For a client who just booked a provider.
  const PushPromptCard.booking({Key? key, EdgeInsets margin = EdgeInsets.zero})
      : this(
          key: key,
          placement: 'client_booking',
          title: 'Know the moment they reply',
          message: 'Get notified when your booking is confirmed or changes, and before your appointment.',
          margin: margin,
        );

  static const Duration snooze = Duration(days: 14);

  /// Identifies where the card sits, so each place snoozes on its own.
  final String placement;
  final String title;
  final String message;
  final EdgeInsets margin;

  @override
  ConsumerState<PushPromptCard> createState() => _PushPromptCardState();
}

class _PushPromptCardState extends ConsumerState<PushPromptCard> {
  bool _dismissed = false;
  bool _working = false;

  String? get _key {
    final userId = ref.read(userProfileProvider).value?.rawUser.id;
    return userId == null ? null : 'push_prompt_dismissed.${widget.placement}.$userId';
  }

  bool get _snoozed {
    final key = _key;
    if (key == null) return true;
    final at = ref.read(sharedPreferencesProvider).getInt(key);
    if (at == null) return false;
    return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(at)) < PushPromptCard.snooze;
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    final key = _key;
    if (key == null) return;
    try {
      await ref.read(sharedPreferencesProvider).setInt(key, DateTime.now().millisecondsSinceEpoch);
    } catch (e, st) {
      AppLogger.e('Saving the push prompt snooze failed', tag: 'PushPrompt', error: e, stackTrace: st);
    }
  }

  Future<void> _enable() async {
    HapticFeedback.selectionClick();
    setState(() => _working = true);
    try {
      await ref.read(pushNotificationsProvider.notifier).enable();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(pushNotificationsProvider).value;
    final show = !_dismissed && (status == PushStatus.off || status == PushStatus.blocked) && !_snoozed;
    final scheme = context.colorScheme;
    final blocked = status == PushStatus.blocked;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !show
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: widget.margin,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.peach.withValues(alpha: 0.35), AppTheme.primaryPink.withValues(alpha: 0.16)],
                  ),
                  border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.notifications_active_rounded, color: scheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scheme.onSurface),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            blocked ? '${widget.message} Notifications are off in your phone settings.' : widget.message,
                            style: TextStyle(fontSize: 13, height: 1.35, color: scheme.onSurface.withValues(alpha: 0.65)),
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: _working ? null : _enable,
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.onSurface,
                              foregroundColor: scheme.surface,
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                            ),
                            child: Text(blocked ? 'Open settings' : 'Turn on notifications'),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Not now',
                      visualDensity: VisualDensity.compact,
                      onPressed: _dismiss,
                      icon: Icon(Icons.close_rounded, size: 18, color: scheme.onSurface.withValues(alpha: 0.45)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
