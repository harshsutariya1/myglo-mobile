import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../shared/bookings/models/client_address.dart';

/// Text controllers behind an [AddressForm], owned by the screen so input
/// survives rebuilds.
class AddressFormControllers {
  AddressFormControllers({ClientAddress? initial, String accessNotes = ''})
      : line1 = TextEditingController(text: initial?.line1 ?? ''),
        unit = TextEditingController(text: initial?.unit ?? ''),
        suburb = TextEditingController(text: initial?.suburb ?? ''),
        postcode = TextEditingController(text: initial?.postcode ?? ''),
        accessNotes = TextEditingController(text: accessNotes),
        state = ValueNotifier(initial?.state ?? AustralianState.qld);

  final TextEditingController line1;
  final TextEditingController unit;
  final TextEditingController suburb;
  final TextEditingController postcode;
  final TextEditingController accessNotes;
  final ValueNotifier<AustralianState> state;

  ClientAddress get address => ClientAddress(
        line1: line1.text.trim(),
        unit: unit.text.trim(),
        suburb: suburb.text.trim(),
        state: state.value,
        postcode: postcode.text.trim(),
      );

  void fill(ClientAddress address) {
    line1.text = address.line1;
    unit.text = address.unit ?? '';
    suburb.text = address.suburb;
    postcode.text = address.postcode;
    state.value = address.state;
  }

  void dispose() {
    line1.dispose();
    unit.dispose();
    suburb.dispose();
    postcode.dispose();
    accessNotes.dispose();
    state.dispose();
  }
}

/// Australian street address entry with inline validation.
class AddressForm extends StatelessWidget {
  const AddressForm({
    super.key,
    required this.formKey,
    required this.controllers,
    required this.onChanged,
    this.providerName,
    this.enabled = true,
  });

  final GlobalKey<FormState> formKey;
  final AddressFormControllers controllers;
  final VoidCallback onChanged;
  final String? providerName;
  final bool enabled;

  static const int maxAccessNotesLength = 300;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Field(
            controller: controllers.line1,
            label: 'Street address',
            hint: 'e.g. 12 Smith Street',
            icon: Icons.home_outlined,
            validator: ClientAddress.validateLine1,
            onChanged: onChanged,
            enabled: enabled,
            autofillHints: const [AutofillHints.streetAddressLine1],
            textInputAction: TextInputAction.next,
            maxLength: ClientAddress.maxLine1Length,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: controllers.unit,
            label: 'Unit, apartment or level (optional)',
            icon: Icons.apartment_rounded,
            validator: ClientAddress.validateUnit,
            onChanged: onChanged,
            enabled: enabled,
            autofillHints: const [AutofillHints.streetAddressLine2],
            textInputAction: TextInputAction.next,
            maxLength: ClientAddress.maxUnitLength,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: controllers.suburb,
            label: 'Suburb',
            hint: 'e.g. Southport',
            icon: Icons.location_city_rounded,
            validator: ClientAddress.validateSuburb,
            onChanged: onChanged,
            enabled: enabled,
            autofillHints: const [AutofillHints.addressCity],
            textInputAction: TextInputAction.next,
            maxLength: ClientAddress.maxSuburbLength,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ValueListenableBuilder<AustralianState>(
                  valueListenable: controllers.state,
                  builder: (context, state, _) => DropdownButtonFormField<AustralianState>(
                    // Keyed so filling a saved address updates the field.
                    key: ValueKey(state),
                    initialValue: state,
                    isExpanded: true,
                    decoration: _decoration(context, label: 'State', icon: Icons.map_outlined),
                    borderRadius: BorderRadius.circular(16),
                    items: [
                      for (final value in AustralianState.values)
                        DropdownMenuItem(value: value, child: Text(value.code)),
                    ],
                    onChanged: enabled
                        ? (value) {
                            if (value == null) return;
                            controllers.state.value = value;
                            onChanged();
                          }
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  controller: controllers.postcode,
                  label: 'Postcode',
                  hint: '4217',
                  icon: Icons.markunread_mailbox_outlined,
                  validator: ClientAddress.validatePostcode,
                  onChanged: onChanged,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                  autofillHints: const [AutofillHints.postalCode],
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Field(
            controller: controllers.accessNotes,
            label: providerName == null ? 'Access notes (optional)' : 'Notes for $providerName (optional)',
            hint: 'Parking, gate code, which door to knock on…',
            icon: Icons.sticky_note_2_outlined,
            onChanged: onChanged,
            enabled: enabled,
            maxLines: 3,
            maxLength: maxAccessNotesLength,
            textInputAction: TextInputAction.newline,
          ),
        ],
      ),
    );
  }
}

InputDecoration _decoration(BuildContext context, {required String label, String? hint, required IconData icon}) {
  final scheme = context.colorScheme;
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon, size: 20),
    filled: true,
    fillColor: scheme.onSurface.withValues(alpha: 0.025),
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: border(scheme.onSurface.withValues(alpha: 0.1)),
    enabledBorder: border(scheme.onSurface.withValues(alpha: 0.1)),
    focusedBorder: border(scheme.primary, 1.6),
    errorBorder: border(scheme.error),
    focusedErrorBorder: border(scheme.error, 1.6),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    required this.onChanged,
    required this.enabled,
    this.hint,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.autofillHints,
    this.textInputAction,
    this.maxLines = 1,
    this.maxLength,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final VoidCallback onChanged;
  final bool enabled;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      validator: validator,
      keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      textCapitalization: maxLines > 1 ? TextCapitalization.sentences : TextCapitalization.words,
      maxLines: maxLines,
      minLines: 1,
      maxLength: maxLength,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onChanged: (_) => onChanged(),
      decoration: _decoration(context, label: label, hint: hint, icon: icon),
    );
  }
}
