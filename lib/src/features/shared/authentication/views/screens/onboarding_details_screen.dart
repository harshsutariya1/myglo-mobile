import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/snackbar_utils.dart';
import '../../models/user_role.dart';
import '../../controllers/onboarding_controller.dart';
import '../widgets/onboarding_steps/name_step.dart';
import '../widgets/onboarding_steps/business_name_step.dart';
import '../widgets/onboarding_steps/address_step.dart';
import '../widgets/onboarding_steps/profile_picture_step.dart';
import '../widgets/onboarding_steps/phone_number_step.dart';
import '../widgets/onboarding_steps/step_progress_indicator.dart';

class OnboardingDetailsScreen extends ConsumerStatefulWidget {
  final UserRole role;

  const OnboardingDetailsScreen({super.key, required this.role});

  @override
  ConsumerState<OnboardingDetailsScreen> createState() =>
      _OnboardingDetailsScreenState();
}

class _OnboardingDetailsScreenState
    extends ConsumerState<OnboardingDetailsScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _providerNameController = TextEditingController();
  final _addressTextController = TextEditingController();
  
  File? _profileImage;
  
  late final PageController _pageController;
  late final List<GlobalKey<FormState>?> _formKeys;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    if (widget.role == UserRole.provider) {
      _formKeys = [
        GlobalKey<FormState>(), // Name
        GlobalKey<FormState>(), // Business Name
        GlobalKey<FormState>(), // Address
        null,                   // Profile Picture (No validation)
        GlobalKey<FormState>(), // Phone
      ];
    } else {
      _formKeys = [
        GlobalKey<FormState>(), // Name
        null,                   // Profile Picture (No validation)
        GlobalKey<FormState>(), // Phone
      ];
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _providerNameController.dispose();
    _addressTextController.dispose();
    super.dispose();
  }

  int get _totalSteps => widget.role == UserRole.provider ? 5 : 3;

  bool get _canSkip {
    if (widget.role == UserRole.provider) {
      return _currentStep == 3 || _currentStep == 4; // Profile Pic or Phone
    } else {
      return _currentStep == 1 || _currentStep == 2; // Profile Pic or Phone
    }
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

  void _nextStep() {
    final formKey = _formKeys[_currentStep];
    if (formKey != null && !formKey.currentState!.validate()) {
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submitDetails();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.pop();
    }
  }

  void _skipStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submitDetails();
    }
  }

  Future<void> _submitDetails() async {
    final controller = ref.read(onboardingControllerProvider.notifier);

    await controller.submitDetails(
      role: widget.role,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      providerName: _providerNameController.text.trim(),
      addressText: _addressTextController.text.trim(),
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

  List<Widget> _buildSteps() {
    if (widget.role == UserRole.provider) {
      return [
        NameStep(
          firstNameController: _firstNameController,
          lastNameController: _lastNameController,
          formKey: _formKeys[0]!,
        ),
        BusinessNameStep(
          providerNameController: _providerNameController,
          formKey: _formKeys[1]!,
        ),
        AddressStep(
          addressTextController: _addressTextController,
          formKey: _formKeys[2]!,
        ),
        ProfilePictureStep(
          role: widget.role,
          profileImage: _profileImage,
          onPickImage: _pickImage,
        ),
        PhoneNumberStep(
          phoneController: _phoneController,
          formKey: _formKeys[4]!,
        ),
      ];
    } else {
      return [
        NameStep(
          firstNameController: _firstNameController,
          lastNameController: _lastNameController,
          formKey: _formKeys[0]!,
        ),
        ProfilePictureStep(
          role: widget.role,
          profileImage: _profileImage,
          onPickImage: _pickImage,
        ),
        PhoneNumberStep(
          phoneController: _phoneController,
          formKey: _formKeys[2]!,
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final isLoading = state.isLoading;
    final steps = _buildSteps();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: isLoading ? null : _previousStep,
        ),
        title: StepProgressIndicator(
          totalSteps: _totalSteps,
          currentStep: _currentStep,
        ),
        centerTitle: true,
        actions: [
          if (_canSkip)
            TextButton(
              onPressed: isLoading ? null : _skipStep,
              child: Text(
                'Maybe later',
                style: TextStyle(
                  color: context.colorScheme.tertiary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable swiping
                children: steps.map((step) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: step,
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _nextStep,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
