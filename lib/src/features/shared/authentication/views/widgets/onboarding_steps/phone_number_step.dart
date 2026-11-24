import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../../core/utils/phone_numbers.dart';
import '../../../../../../core/theme/app_theme.dart';

class PhoneNumberStep extends StatelessWidget {
  final TextEditingController phoneController;
  final GlobalKey<FormState> formKey;

  const PhoneNumberStep({
    super.key,
    required this.phoneController,
    required this.formKey,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What\'s your number?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: phoneController,
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              border: UnderlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d+\s()-]')),
              LengthLimitingTextInputFormatter(20),
            ],
            validator: PhoneNumbers.validateRequired,
          ),
        ],
      ),
    );
  }
}
