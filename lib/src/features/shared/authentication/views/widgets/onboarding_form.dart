import 'package:flutter/material.dart';
import '../../models/user_role.dart';

class OnboardingForm extends StatelessWidget {
  final UserRole role;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController businessNameController;
  final TextEditingController phoneController;

  const OnboardingForm({
    super.key,
    required this.role,
    required this.firstNameController,
    required this.lastNameController,
    required this.businessNameController,
    required this.phoneController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: firstNameController,
          decoration: const InputDecoration(
            labelText: 'First name',
            border: OutlineInputBorder(),
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
            border: OutlineInputBorder(),
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
        const SizedBox(height: 16),
        if (role == UserRole.business) ...[
          TextFormField(
            controller: businessNameController,
            decoration: const InputDecoration(
              labelText: 'Business Name',
              border: OutlineInputBorder(),
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
          const SizedBox(height: 16),
        ],
        TextFormField(
          controller: phoneController,
          decoration: const InputDecoration(
            labelText: 'Phone number (Optional)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            if (value != null && value.trim().isNotEmpty) {
              if (value.trim().length < 7) {
                return 'Please enter a valid phone number';
              }
            }
            return null;
          },
        ),
      ],
    );
  }
}
