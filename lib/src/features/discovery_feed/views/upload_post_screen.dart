import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/authentication/controllers/user_profile_provider.dart';
import '../../providers/provider_profiles/models/service_model.dart';
import '../models/post_repository.dart';
import '../controllers/upload_post_controller.dart';
import 'widgets/provider_search_bottom_sheet.dart';

class UploadPostScreen extends ConsumerStatefulWidget {
  const UploadPostScreen({super.key});

  @override
  ConsumerState<UploadPostScreen> createState() => _UploadPostScreenState();
}

class _UploadPostScreenState extends ConsumerState<UploadPostScreen> {
  final _captionController = TextEditingController();
  final List<File> _images = [];
  final ImagePicker _picker = ImagePicker();

  ProviderSearchResult? _selectedProvider;
  ServiceModel? _selectedService;
  List<ServiceModel> _providerServices = [];

  bool _isLoadingServices = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(userProfileProvider).value;
      if (profile != null && profile.isProvider) {
        _fetchServices(profile.rawUser.id);
      }
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _images.addAll(pickedFiles.map((e) => File(e.path)));
      });
    }
  }

  Future<void> _removeImage(int index) async {
    setState(() {
      _images.removeAt(index);
    });
  }

  Future<void> _fetchServices(String providerId) async {
    setState(() {
      _isLoadingServices = true;
      _selectedService = null;
    });
    
    try {
      final repo = ref.read(postRepositoryProvider);
      final services = await repo.getProviderServices(providerId);
      setState(() {
        _providerServices = services;
      });
    } catch (e) {
      // Ignore or log error
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingServices = false;
        });
      }
    }
  }

  Future<void> _uploadPost() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one image')),
      );
      return;
    }

    final userProfile = ref.read(userProfileProvider).value;
    if (userProfile == null) return;

    final success = await ref.read(uploadPostControllerProvider.notifier).uploadPost(
      authorId: userProfile.rawUser.id,
      images: _images,
      caption: _captionController.text.trim(),
      taggedProviderId: userProfile.isProvider ? null : _selectedProvider?.id,
      serviceId: _selectedService?.id,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post uploaded successfully!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } else {
      final error = ref.read(uploadPostControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload post: $error'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadPostControllerProvider);
    final isUploading = uploadState.isLoading;
    final userProfile = ref.watch(userProfileProvider).value;
    final isProvider = userProfile?.isProvider ?? false;

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: context.colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: context.colorScheme.onSurface),
        title: Text('Create Post', style: TextStyle(color: context.colorScheme.onSurface, fontWeight: FontWeight.bold)),
        actions: [
          if (isUploading)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: context.colorScheme.onSurface, strokeWidth: 2))),
            )
          else
            TextButton(
              onPressed: _images.isNotEmpty ? _uploadPost : null,
              child: Text(
                'Post',
                style: TextStyle(
                  color: _images.isNotEmpty ? context.colorScheme.onSurface : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Caption Input
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: userProfile?.profile.profilePic != null
                      ? NetworkImage(userProfile!.profile.profilePic!)
                      : null,
                  child: userProfile?.profile.profilePic == null
                      ? const Icon(Icons.person, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _captionController,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Write a caption...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Image Selection Grid
            if (_images.isNotEmpty) ...[
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _images.length) {
                      return GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Icon(Icons.add_a_photo, color: Colors.grey),
                        ),
                      );
                    }
                    return Stack(
                      children: [
                        Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: FileImage(_images[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('Add Photos', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
            ],

            Divider(),
            SizedBox(height: 24),

            if (!isProvider) ...[
              // Provider Tagging (Autocomplete)
              Text('Tag Provider (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.colorScheme.onSurface)),
              const SizedBox(height: 12),
              _selectedProvider == null
                  ? InkWell(
                      onTap: () async {
                        final selected = await ProviderSearchBottomSheet.show(context);
                        if (selected != null) {
                          setState(() {
                            _selectedProvider = selected;
                            _selectedService = null;
                          });
                          _fetchServices(selected.id);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.grey),
                            const SizedBox(width: 12),
                            Text('Search for a provider...', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: context.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colorScheme.primary.withValues(alpha: 0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _selectedProvider!.profilePic != null
                              ? NetworkImage(_selectedProvider!.profilePic!)
                              : null,
                          child: _selectedProvider!.profilePic == null
                              ? const Icon(Icons.business, color: Colors.grey)
                              : null,
                        ),
                        title: Text(
                          _selectedProvider!.providerName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _selectedProvider = null;
                              _selectedService = null;
                              _providerServices = [];
                            });
                          },
                        ),
                      ),
                    ),

              // Service Selection
              if (_selectedProvider != null) ...[
                SizedBox(height: 24),
                Text('Tag Service (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.colorScheme.onSurface)),
                const SizedBox(height: 12),
                if (_isLoadingServices)
                  Center(child: CircularProgressIndicator())
                else if (_providerServices.isEmpty)
                  Text('This provider has no services listed.', style: TextStyle(color: Colors.grey))
                else
                  DropdownButtonFormField<ServiceModel>(
                    initialValue: _selectedService,
                    hint: Text('Select a service'),
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.colorScheme.primary)),
                    ),
                    items: _providerServices.map((service) {
                      return DropdownMenuItem(
                        value: service,
                        child: Text(service.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedService = value;
                      });
                    },
                  ),
              ],
            ] else ...[
              // For providers, just show the Service Selection
              Text('Tag Service (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.colorScheme.onSurface)),
              const SizedBox(height: 12),
              if (_isLoadingServices)
                Center(child: CircularProgressIndicator())
              else if (_providerServices.isEmpty)
                Text('You have no services listed yet.', style: TextStyle(color: Colors.grey))
              else
                DropdownButtonFormField<ServiceModel>(
                  initialValue: _selectedService,
                  hint: Text('Select a service'),
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.colorScheme.primary)),
                  ),
                  items: _providerServices.map((service) {
                    return DropdownMenuItem(
                      value: service,
                      child: Text(service.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedService = value;
                    });
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}
