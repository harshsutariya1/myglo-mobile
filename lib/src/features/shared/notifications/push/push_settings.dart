import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'push_notifications_controller.dart';

/// What a push notifications switch shows and does, shared by the provider
/// and client settings screens.
class PushToggleModel {
  const PushToggleModel({required this.value, required this.enabled, required this.subtitle, this.opensSettings = false});

  final bool value;
  final bool enabled;
  final String subtitle;

  /// Tapping goes to the system settings rather than flipping the switch.
  final bool opensSettings;

  static PushToggleModel of(PushStatus? status) => switch (status) {
        null => const PushToggleModel(value: false, enabled: false, subtitle: 'Checking…'),
        PushStatus.on => const PushToggleModel(
            value: true,
            enabled: true,
            subtitle: 'Booking requests, confirmations, changes and reminders',
          ),
        PushStatus.off => const PushToggleModel(
            value: false,
            enabled: true,
            subtitle: 'Off. Turn on to hear about bookings straight away',
          ),
        PushStatus.paused => const PushToggleModel(
            value: false,
            enabled: true,
            subtitle: "Paused on this phone. You'll still see updates in the app",
          ),
        PushStatus.blocked => const PushToggleModel(
            value: false,
            enabled: true,
            subtitle: 'Blocked in your phone settings. Tap to open them',
            opensSettings: true,
          ),
        PushStatus.unsupported => const PushToggleModel(
            value: false,
            enabled: false,
            subtitle: 'Coming soon on this device. Booking updates still arrive in the app and by email',
          ),
      };
}

/// Drives a push notifications switch with an optimistic value while the
/// change is applied.
mixin PushToggleState<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool? pendingPushValue;

  Future<void> setPush(bool on) async {
    final controller = ref.read(pushNotificationsProvider.notifier);
    final status = ref.read(pushNotificationsProvider).value;
    if (status == PushStatus.blocked) {
      await controller.enable();
      return;
    }
    setState(() => pendingPushValue = on);
    try {
      on ? await controller.enable() : await controller.disable();
    } finally {
      if (mounted) setState(() => pendingPushValue = null);
    }
  }
}
