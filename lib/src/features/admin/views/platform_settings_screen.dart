import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../controllers/admin_actions.dart';
import '../controllers/admin_controllers.dart';
import '../models/admin_models.dart';
import '../models/admin_repository.dart';
import 'widgets/admin_widgets.dart';

/// Edits the platform settings. Saving asks for a reason and a fresh
/// authenticator code; the server checks both, applies only the changed
/// values and records them in the audit log.
class PlatformSettingsScreen extends ConsumerWidget {
  const PlatformSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(platformSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Platform settings')),
      body: switch (settings) {
        AsyncData(:final value) => PlatformSettingsForm(key: ValueKey(value.updatedAt), saved: value),
        AsyncError(:final error) => AdminErrorView(error: error, onRetry: () => ref.invalidate(platformSettingsProvider)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// One numeric setting: its key in [PlatformSettings.toChanges], the range
/// the database accepts, and how to read and write it.
class SettingField {
  const SettingField({
    required this.key,
    required this.label,
    required this.help,
    required this.suffix,
    required this.min,
    required this.max,
    required this.read,
    required this.write,
    this.decimals = false,
  });

  final String key;
  final String label;
  final String help;
  final String suffix;
  final num min;
  final num max;
  final bool decimals;
  final num Function(PlatformSettings) read;
  final PlatformSettings Function(PlatformSettings, num) write;
}

/// The editable settings, grouped. Ranges match the CHECK constraints in the
/// admin foundation migration.
final settingGroups = <(String, List<SettingField>)>[
  (
    'Myglo fee',
    [
      SettingField(
        key: 'platform_fee_percent',
        label: 'Myglo fee',
        help: 'Charged to providers on bookings paid in the app. Never on cash. Applies to new bookings.',
        suffix: '%',
        min: 0,
        max: 100,
        decimals: true,
        read: (s) => s.platformFeePercent,
        write: (s, v) => s.copyWith(platformFeePercent: v.toDouble()),
      ),
      SettingField(
        key: 'fee_free_days',
        label: 'Fee-free period',
        help: "Days without the fee, from when each provider's card payments start. Changes apply to every provider.",
        suffix: 'days',
        min: 0,
        max: 3650,
        read: (s) => s.feeFreeDays,
        write: (s, v) => s.copyWith(feeFreeDays: v.toInt()),
      ),
    ],
  ),
  (
    'New provider defaults',
    [
      SettingField(
        key: 'default_cancellation_window_hours',
        label: 'Free cancellation until',
        help: 'Hours before the appointment. Providers can change their own.',
        suffix: 'hours',
        min: 0,
        max: 168,
        read: (s) => s.defaultCancellationWindowHours,
        write: (s, v) => s.copyWith(defaultCancellationWindowHours: v.toInt()),
      ),
      SettingField(
        key: 'default_cancellation_fee_percent',
        label: 'Late-cancellation fee',
        help: 'Share of the booking kept for late cancellations and no-shows (card payments only).',
        suffix: '%',
        min: 0,
        max: 100,
        read: (s) => s.defaultCancellationFeePercent,
        write: (s, v) => s.copyWith(defaultCancellationFeePercent: v.toInt()),
      ),
    ],
  ),
  (
    'Card payments',
    [
      SettingField(
        key: 'checkout_hold_minutes',
        label: 'Checkout hold',
        help: "How long a slot is held while the client pays.",
        suffix: 'min',
        min: 5,
        max: 60,
        read: (s) => s.checkoutHoldMinutes,
        write: (s, v) => s.copyWith(checkoutHoldMinutes: v.toInt()),
      ),
      SettingField(
        key: 'card_request_response_hours',
        label: 'Request reply time',
        help: 'How long a provider has to accept a card request (card holds last about 7 days).',
        suffix: 'hours',
        min: 1,
        max: 156,
        read: (s) => s.cardRequestResponseHours,
        write: (s, v) => s.copyWith(cardRequestResponseHours: v.toInt()),
      ),
      SettingField(
        key: 'card_max_advance_days',
        label: 'Card bookings up to',
        help: 'Days ahead. Further out is cash only (Stripe holds funds for at most 90 days).',
        suffix: 'days',
        min: 1,
        max: 85,
        read: (s) => s.cardMaxAdvanceDays,
        write: (s, v) => s.copyWith(cardMaxAdvanceDays: v.toInt()),
      ),
      SettingField(
        key: 'auto_complete_after_hours',
        label: 'Auto-complete after',
        help: "Card bookings complete this long after they end if the provider hasn't, and the provider is paid.",
        suffix: 'hours',
        min: 1,
        max: 168,
        read: (s) => s.autoCompleteAfterHours,
        write: (s, v) => s.copyWith(autoCompleteAfterHours: v.toInt()),
      ),
      SettingField(
        key: 'report_window_hours',
        label: 'Problem reports until',
        help: 'Hours after the appointment ends that a client can report a problem.',
        suffix: 'hours',
        min: 1,
        max: 168,
        read: (s) => s.reportWindowHours,
        write: (s, v) => s.copyWith(reportWindowHours: v.toInt()),
      ),
    ],
  ),
];

/// An on/off platform setting.
class SettingToggle {
  const SettingToggle({
    required this.key,
    required this.label,
    required this.help,
    required this.read,
    required this.write,
  });

  /// The key `admin_update_platform_settings` expects.
  final String key;
  final String label;
  final String help;
  final bool Function(PlatformSettings) read;
  final PlatformSettings Function(PlatformSettings, bool) write;
}

/// The on/off settings, in the order shown.
final List<(String, List<SettingToggle>)> settingToggleGroups = [
  (
    'Accounts',
    [
      SettingToggle(
        key: 'provider_self_deletion',
        label: 'Providers can delete their own account',
        help: 'Off: providers hide their business instead and email support to close the account. '
            'Turn on if a store reviewer requires in-app deletion for providers.',
        read: (s) => s.providerSelfDeletion,
        write: (s, v) => s.copyWith(providerSelfDeletion: v),
      ),
    ],
  ),
];

class PlatformSettingsForm extends ConsumerStatefulWidget {
  const PlatformSettingsForm({super.key, required this.saved});

  final PlatformSettings saved;

  @override
  ConsumerState<PlatformSettingsForm> createState() => _PlatformSettingsFormState();
}

class _PlatformSettingsFormState extends ConsumerState<PlatformSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late PlatformSettings _edited = widget.saved;
  bool _saving = false;

  /// Bumped on discard so the fields rebuild with the saved values.
  int _generation = 0;

  Map<String, Object> get _changes => widget.saved.changesTo(_edited);

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final changes = _changes;
    if (changes.isEmpty) return;
    final labels = {for (final (_, fields) in settingGroups) for (final f in fields) f.key: f};
    final toggles = {for (final (_, items) in settingToggleGroups) for (final t in items) t.key: t};
    String onOff(Object? value) => value == true ? 'On' : 'Off';
    final summary = changes.entries.map((e) {
      final before = widget.saved.toChanges()[e.key];
      final toggle = toggles[e.key];
      if (toggle != null) return '${toggle.label}: ${onOff(before)} → ${onOff(e.value)}';
      final field = labels[e.key];
      return '${field?.label ?? e.key}: $before → ${e.value} ${field?.suffix ?? ''}'.trim();
    }).join('\n');

    final reason = await askAdminReason(context, title: 'Save platform settings', summary: summary);
    if (reason == null || !mounted) return;

    setState(() => _saving = true);
    final saved = await runAdminAction(
      context,
      ref,
      sensitive: true,
      confirmMessage: 'Enter a code from your authenticator app to change platform settings.',
      successMessage: 'Platform settings saved',
      action: () => ref.read(adminRepositoryProvider).updatePlatformSettings(changes, reason: reason),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved != null) ref.invalidate(platformSettingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final dirty = _changes.isNotEmpty;
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                for (final (title, fields) in settingGroups)
                  AdminSection(
                    title: title,
                    children: [
                      for (final field in fields)
                        _NumberSetting(
                          key: ValueKey('${field.key}-$_generation'),
                          field: field,
                          initial: field.read(widget.saved),
                          changed: field.read(_edited) != field.read(widget.saved),
                          onChanged: (value) => setState(() => _edited = field.write(_edited, value)),
                        ),
                    ],
                  ),
                for (final (title, toggles) in settingToggleGroups)
                  AdminSection(
                    title: title,
                    children: [
                      for (final toggle in toggles)
                        // Its own Material, so the tile's ink isn't hidden by
                        // the section's background.
                        Material(
                          type: MaterialType.transparency,
                          child: SwitchListTile.adaptive(
                            key: ValueKey('${toggle.key}-$_generation'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              toggle.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: toggle.read(_edited) != toggle.read(widget.saved)
                                    ? scheme.secondary
                                    : scheme.onSurface,
                              ),
                            ),
                            subtitle: Text(
                              toggle.help,
                              style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.6)),
                            ),
                            value: toggle.read(_edited),
                            onChanged:
                                _saving ? null : (value) => setState(() => _edited = toggle.write(_edited, value)),
                          ),
                        ),
                    ],
                  ),
                AdminSection(
                  title: 'Maps',
                  children: const [
                    AdminInfoRow(label: 'Map provider', value: 'Google Maps (the only provider in this version)'),
                  ],
                ),
                if (widget.saved.updatedAt != null)
                  Text(
                    'Last changed ${adminDateTime(widget.saved.updatedAt!)}'
                    '${widget.saved.updatedBy == null ? '' : ' by ${widget.saved.updatedBy}'}.',
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.55)),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  if (dirty)
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                                _edited = widget.saved;
                                _generation++;
                              }),
                      child: const Text('Discard'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: dirty && !_saving ? _save : null,
                    child: _saving
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : Text(dirty ? 'Save ${_changes.length} ${_changes.length == 1 ? 'change' : 'changes'}' : 'No changes'),
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

class _NumberSetting extends StatefulWidget {
  const _NumberSetting({
    super.key,
    required this.field,
    required this.initial,
    required this.changed,
    required this.onChanged,
  });

  final SettingField field;
  final num initial;
  final bool changed;
  final ValueChanged<num> onChanged;

  @override
  State<_NumberSetting> createState() => _NumberSettingState();
}

class _NumberSettingState extends State<_NumberSetting> {
  late final _controller = TextEditingController(text: _format(widget.initial));

  String _format(num value) => widget.field.decimals
      ? (value == value.roundToDouble() ? value.toInt().toString() : value.toString())
      : value.toInt().toString();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? text) {
    final value = num.tryParse(text?.trim() ?? '');
    final field = widget.field;
    if (value == null) return 'Enter a number';
    if (!field.decimals && value != value.roundToDouble()) return 'Whole numbers only';
    if (value < field.min || value > field.max) return 'Between ${field.min} and ${field.max}';
    if (field.decimals && ((value * 100).round() / 100) != value) return 'Up to 2 decimal places';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final field = widget.field;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: _controller,
        keyboardType: TextInputType.numberWithOptions(decimal: field.decimals),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(field.decimals ? r'[0-9.]' : r'[0-9]'))],
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: _validate,
        onChanged: (text) {
          final value = num.tryParse(text.trim());
          if (value != null && _validate(text) == null) widget.onChanged(value);
        },
        decoration: InputDecoration(
          labelText: field.label,
          helperText: field.help,
          helperMaxLines: 3,
          suffixText: field.suffix,
          border: const OutlineInputBorder(),
          enabledBorder: widget.changed
              ? OutlineInputBorder(borderSide: BorderSide(color: scheme.secondary, width: 1.6))
              : null,
        ),
      ),
    );
  }
}
