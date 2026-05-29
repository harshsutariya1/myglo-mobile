import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../domain/user_role.dart';
import '../../application/user_profile_provider.dart';
import '../../data/user_repository.dart';

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
  bool _isLoading = false;

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
      if (mounted) context.showAppSnackBar('Failed to pick image', isError: true);
    }
  }

  Future<void> _submitDetails() async {
    if (!_formKey.currentState!.validate()) return;

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phoneText = _phoneController.text.trim();
    final phone = phoneText.isEmpty ? null : phoneText;
    final businessName = _businessNameController.text.trim();

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('No user found');

      String? profilePicUrl;

      // Upload profile picture if selected
      if (_profileImage != null) {
        developer.log('Uploading profile picture...', name: 'OnboardingDetailsScreen');
        final fileExt = _profileImage!.path.split('.').last;
        final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        
        await supabase.storage.from('profile-pics').upload(
              fileName,
              _profileImage!,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
            );

        profilePicUrl = supabase.storage.from('profile-pics').getPublicUrl(fileName);
      }

      developer.log(
        'Calling userRepository.updateOnboardingDetails',
        name: 'OnboardingDetailsScreen',
      );

      final userRepo = ref.read(userRepositoryProvider);
      
      await userRepo.updateOnboardingDetails(
        id: user.id,
        role: widget.role.name,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        profilePic: profilePicUrl,
        businessName: widget.role == UserRole.business ? businessName : null,
      );

      // Invalidate the profile provider so it re-fetches with new data
      ref.invalidate(userProfileProvider);

      developer.log(
        'Successfully saved onboarding details',
        name: 'OnboardingDetailsScreen',
      );

      if (mounted) {
        context.go('/main');
      }
    } catch (e) {
      developer.log(
        'Error saving details: $e',
        level: 1000,
        name: 'OnboardingDetailsScreen',
      );
      if (mounted) context.showAppSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    backgroundColor: AppTheme.burntOrange.withValues(alpha: 0.2),
                    backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
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

              TextFormField(
                controller: _firstNameController,
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
                controller: _lastNameController,
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

              if (widget.role == UserRole.business) ...[
                TextFormField(
                  controller: _businessNameController,
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
                controller: _phoneController,
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
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitDetails,
                  child: _isLoading
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
