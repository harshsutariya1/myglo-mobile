import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_theme.dart';

class BusinessNameStep extends StatelessWidget {
  final TextEditingController providerNameController;
  final GlobalKey<FormState> formKey;

  const BusinessNameStep({
    super.key,
    required this.providerNameController,
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
            'What\'s the name of your business?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: providerNameController,
            decoration: const InputDecoration(
              labelText: 'Business name',
              border: UnderlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Business name is required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
