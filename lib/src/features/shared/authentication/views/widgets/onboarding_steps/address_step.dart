import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_theme.dart';

class AddressStep extends StatelessWidget {
  final TextEditingController addressTextController;
  final GlobalKey<FormState> formKey;

  const AddressStep({
    super.key,
    required this.addressTextController,
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
            'Where are you based?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: addressTextController,
            decoration: const InputDecoration(
              labelText: 'Physical Address',
              border: UnderlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Address is required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
