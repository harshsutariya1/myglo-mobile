import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_theme.dart';

class NameStep extends StatelessWidget {
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final GlobalKey<FormState> formKey;

  const NameStep({
    super.key,
    required this.firstNameController,
    required this.lastNameController,
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
            'What\'s your name?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: firstNameController,
            decoration: const InputDecoration(
              labelText: 'First name',
              border: UnderlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'First name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: lastNameController,
            decoration: const InputDecoration(
              labelText: 'Last name',
              border: UnderlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Last name is required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
