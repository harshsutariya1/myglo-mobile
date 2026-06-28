import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/snackbar_utils.dart';
import '../../models/user_role.dart';
import '../../controllers/onboarding_controller.dart';
import '../widgets/onboarding_form.dart';

class OnboardingDetailsScreen extends ConsumerStatefulWidget {
  final UserRole role;

  const OnboardingDetailsScreen({super.key, required this.role});

  @override
  ConsumerState<OnboardingDetailsScreen> createState() =>
      _OnboardingDetailsScreenState();
}

class _OnboardingDetailsScreenState
    extends ConsumerState<OnboardingDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessNameController = TextEditingController();

  File? _profileImage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        context.showAppSnackBar('Failed to pick image', isError: true);
      }
    }
  }

  Future<void> _submitDetails() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(onboardingControllerProvider.notifier);

    await controller.submitDetails(
      role: widget.role,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      businessName: _businessNameController.text.trim(),
      profileImage: _profileImage,
    );

    final state = ref.read(onboardingControllerProvider);
    if (state.hasError) {
      if (mounted) {
        context.showAppSnackBar(state.error.toString(), isError: true);
      }
    } else {
      if (mounted) {
        context.go('/main');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Let\'s get to know you!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkRed,
                  ),
                ),
                const SizedBox(height: 32),

                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.burntOrange.withValues(
                        alpha: 0.2,
                      ),
                      backgroundImage: _profileImage != null
                          ? FileImage(_profileImage!)
                          : null,
                      child: _profileImage == null
                          ? const Icon(
                              Icons.add_a_photo,
                              size: 40,
                              color: AppTheme.burntOrange,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Add a profile picture (Optional)',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 32),

                OnboardingForm(
                  role: widget.role,
                  firstNameController: _firstNameController,
                  lastNameController: _lastNameController,
                  businessNameController: _businessNameController,
                  phoneController: _phoneController,
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submitDetails,
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Complete'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
