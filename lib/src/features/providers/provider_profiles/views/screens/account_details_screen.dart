import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../../shared/authentication/controllers/edit_account_controller.dart';
import '../widgets/profile_pic_picker.dart';

class AccountDetailsScreen extends ConsumerStatefulWidget {
  const AccountDetailsScreen({super.key});

  @override
  ConsumerState<AccountDetailsScreen> createState() =>
      _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends ConsumerState<AccountDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _providerNameController;
  late TextEditingController _addressTextController;
  File? _newProfilePic;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final userProfile = ref.read(userProfileProvider).value;
    final profile = userProfile?.profile;
    _firstNameController = TextEditingController(
      text: profile?.firstName ?? '',
    );
    _lastNameController = TextEditingController(text: profile?.lastName ?? '');
    _phoneController = TextEditingController(text: profile?.phoneNumber ?? '');
    _providerNameController = TextEditingController(
      text: userProfile?.providerDetails?.providerName ?? '',
    );
    _addressTextController = TextEditingController(
      text: userProfile?.providerDetails?.addressText ?? '',
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _providerNameController.dispose();
    _addressTextController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() {
        _newProfilePic = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveDetails() async {
    if (!_formKey.currentState!.validate()) return;

    final userProfile = ref.read(userProfileProvider).value;
    if (userProfile == null) return;

    setState(() => _isLoading = true);

    try {
      await ref
          .read(editAccountControllerProvider)
          .updateProfile(
            id: userProfile.profile.id,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            phone: _phoneController.text.trim(),
            providerName: userProfile.isProvider
                ? _providerNameController.text.trim()
                : null,
            addressText: userProfile.isProvider
                ? _addressTextController.text.trim()
                : null,
            newProfilePic: _newProfilePic,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider).value;
    final profile = userProfile?.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Account Details')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    ProfilePicPicker(
                      newProfilePic: _newProfilePic,
                      existingProfilePicUrl: profile?.profilePic,
                      onPickImage: _pickImage,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Please enter first name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Please enter last name'
                          : null,
                    ),
                    if (userProfile?.isProvider == true) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _providerNameController,
                        decoration: const InputDecoration(
                          labelText: 'Provider Name',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Please enter provider name'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressTextController,
                        decoration: const InputDecoration(
                          labelText: 'Physical Address',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Please enter physical address'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPink,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _saveDetails,
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
