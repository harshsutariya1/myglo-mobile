import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../shared/authentication/controllers/user_profile_provider.dart';
import '../widgets/profile_pic_picker.dart';
import '../../controllers/edit_provider_profile_controller.dart';

class EditProviderProfileScreen extends ConsumerStatefulWidget {
  const EditProviderProfileScreen({super.key});

  @override
  ConsumerState<EditProviderProfileScreen> createState() =>
      _EditProviderProfileScreenState();
}

class _EditProviderProfileScreenState
    extends ConsumerState<EditProviderProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _providerNameController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  late TextEditingController _addressTextController;

  bool _isEmailPublic = false;
  bool _isPhonePublic = false;

  File? _newProfilePic;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final profileState = ref.read(userProfileProvider).value;
    final profile = profileState?.profile;
    final providerDetails = profileState?.providerDetails;

    _firstNameController = TextEditingController(text: profile?.firstName ?? '');
    _lastNameController = TextEditingController(text: profile?.lastName ?? '');
    _providerNameController = TextEditingController(text: providerDetails?.providerName ?? '');
    _phoneController = TextEditingController(text: profile?.phoneNumber ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
    _addressTextController = TextEditingController(text: providerDetails?.addressText ?? '');
    
    _isEmailPublic = profile?.isEmailPublic ?? false;
    _isPhonePublic = profile?.isPhonePublic ?? false;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _providerNameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _addressTextController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _newProfilePic = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    final profileState = ref.read(userProfileProvider).value;
    if (profileState == null) return;

    final success = await ref
        .read(editProviderProfileControllerProvider.notifier)
        .saveProfile(
          id: profileState.rawUser.id,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          providerName: _providerNameController.text.trim(),
          addressText: _addressTextController.text.trim(),
          phone: _phoneController.text.trim(),
          bio: _bioController.text.trim(),
          isEmailPublic: _isEmailPublic,
          isPhonePublic: _isPhonePublic,
          newProfilePic: _newProfilePic,
        );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      final errorState = ref.read(editProviderProfileControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorState.error?.toString() ?? 'Failed to update profile'
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider).value;
    final editState = ref.watch(editProviderProfileControllerProvider);
    final isLoading = editState.isLoading;

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: context.colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: context.colorScheme.onSurface),
        title: Text(
          'Edit Business Profile',
          style: TextStyle(
            color: context.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: userProfile == null
          ? Center(child: CircularProgressIndicator(color: context.colorScheme.onSurface))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ProfilePicPicker(
                        newProfilePic: _newProfilePic,
                        existingProfilePicUrl: userProfile.profile.profilePic,
                        onPickImage: _pickImage,
                      ),
                    ),
                    SizedBox(height: 32),
                    
                    // Business Information Section
                    Text(
                      'Business Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _providerNameController,
                      label: 'Business / Salon Name',
                      icon: Icons.storefront,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _addressTextController,
                      label: 'Business Address',
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 32),
                    
                    // Basic Information Section
                    Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _firstNameController,
                      label: 'First Name',
                      icon: Icons.person_outline,
                      validator: (val) => val == null || val.isEmpty
                          ? 'First name is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _lastNameController,
                      label: 'Last Name',
                      icon: Icons.person_outline,
                      validator: (val) => val == null || val.isEmpty
                          ? 'Last name is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _bioController,
                      label: 'Bio',
                      icon: Icons.info_outline,
                      maxLines: 3,
                    ),
                    
                    SizedBox(height: 32),
                    
                    // Contact Information Section
                    Text(
                      'Contact Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    
                    SizedBox(height: 32),
                    
                    // Privacy Settings Section
                    Text(
                      'Privacy Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Make Email Public'),
                      subtitle: const Text(
                        'Allow others to see your email address',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _isEmailPublic,
                      activeThumbColor: context.colorScheme.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() => _isEmailPublic = val);
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Make Phone Number Public'),
                      subtitle: const Text(
                        'Allow others to see your phone number',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _isPhonePublic,
                      activeThumbColor: context.colorScheme.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() => _isPhonePublic = val);
                      },
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // Save Button
                    ElevatedButton(
                      onPressed: isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colorScheme.onSurface,
                        foregroundColor: context.colorScheme.surface,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: context.colorScheme.surface,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: maxLines == 1 ? Icon(icon, color: Colors.grey) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
