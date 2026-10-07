import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

/// Bottom sheet with a time wheel in [minuteInterval] steps. Times are
/// minutes after midnight; [allowMidnightEnd] maps 12:00 am to 1440 (the end
/// of the day) for closing times.
Future<int?> showTimeWheelSheet(
  BuildContext context, {
  required String title,
  required int initialMinutes,
  int minuteInterval = 5,
  bool allowMidnightEnd = false,
}) {
  final initial = initialMinutes % 1440;
  var selected = initial - initial % minuteInterval;
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (sheetContext) {
      final scheme = sheetContext.colorScheme;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface)),
              SizedBox(
                height: 200,
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: Theme.of(sheetContext).brightness,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(fontSize: 21, color: scheme.onSurface),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    minuteInterval: minuteInterval,
                    initialDateTime: DateTime(2000, 1, 1).add(Duration(minutes: selected)),
                    onDateTimeChanged: (value) => selected = value.hour * 60 + value.minute,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(allowMidnightEnd && selected == 0 ? 1440 : selected),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.onSurface,
                  foregroundColor: scheme.surface,
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                ),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// One choice in [showChoiceSheet].
typedef SheetChoice<T> = ({T value, String label, String? detail});

/// Bottom sheet listing [choices]; returns the one picked.
Future<T?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  String? message,
  required List<SheetChoice<T>> choices,
  required T selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (sheetContext) {
      final scheme = sheetContext.colorScheme;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface)),
              if (message != null) ...[
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(fontSize: 14, height: 1.45, color: scheme.onSurface.withValues(alpha: 0.65)),
                ),
              ],
              const SizedBox(height: 12),
              RadioGroup<T>(
                groupValue: selected,
                onChanged: (value) => Navigator.of(sheetContext).pop(value),
                child: Column(
                  children: [
                    for (final choice in choices)
                      RadioListTile<T>(
                        value: choice.value,
                        contentPadding: EdgeInsets.zero,
                        activeColor: scheme.secondary,
                        title: Text(
                          choice.label,
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: scheme.onSurface),
                        ),
                        subtitle: choice.detail == null
                            ? null
                            : Text(
                                choice.detail!,
                                style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6)),
                              ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Bottom bar with a single save button, for edit screens.
class SaveBar extends StatelessWidget {
  const SaveBar({super.key, required this.label, required this.onPressed, this.busy = false, this.message});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  /// Optional line above the button (e.g. why it's disabled).
  final String? message;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.onSurface.withValues(alpha: 0.07))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (message != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.destructive),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                onPressed: busy ? null : onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.onSurface,
                  foregroundColor: scheme.surface,
                  minimumSize: const Size(0, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                ),
                child: busy
                    ? SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: scheme.surface),
                      )
                    : Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks whether to throw away unsaved edits. Returns true to leave.
Future<bool> confirmDiscardChanges(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Discard changes?'),
      content: const Text("You have changes that haven't been saved."),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep editing')),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.destructive, foregroundColor: Colors.white),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  return discard ?? false;
}
