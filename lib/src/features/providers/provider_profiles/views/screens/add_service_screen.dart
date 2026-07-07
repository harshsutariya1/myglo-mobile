import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../controllers/add_service_controller.dart';

class AddServiceScreen extends ConsumerStatefulWidget {
  const AddServiceScreen({super.key});

  @override
  ConsumerState<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends ConsumerState<AddServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();
  final _categoryController = TextEditingController();
  
  File? _selectedImage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final success = await ref.read(addServiceControllerProvider.notifier).addService(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        durationMinutes: int.parse(_durationController.text.trim()),
        category: _categoryController.text.trim().isNotEmpty ? _categoryController.text.trim() : null,
        imageFile: _selectedImage,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service added successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } else {
        final error = ref.read(addServiceControllerProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add service: $error'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addServiceControllerProvider);
    final isLoading = state is AsyncLoading;

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        title: Text('Add Service', style: TextStyle(color: context.colorScheme.onSurface, fontWeight: FontWeight.bold)),
        backgroundColor: context.colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: context.colorScheme.onSurface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Picker Section
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: context.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    image: _selectedImage != null
                        ? DecorationImage(
                            image: FileImage(_selectedImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    border: _selectedImage == null
                        ? Border.all(color: context.colorScheme.outline.withAlpha(128), width: 2, style: BorderStyle.solid)
                        : null,
                  ),
                  child: _selectedImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 48, color: context.colorScheme.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(
                              'Add Service Image',
                              style: TextStyle(
                                color: context.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                                onPressed: _pickImage,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Service Name',
                  prefixIcon: const Icon(Icons.design_services),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.colorScheme.primary)),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                decoration: InputDecoration(
                  labelText: 'Category (Optional)',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.colorScheme.primary)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.colorScheme.primary)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Price (\$)',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.colorScheme.primary)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (double.tryParse(value) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Duration (min)',
                        prefixIcon: const Icon(Icons.timer),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.colorScheme.primary)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (int.tryParse(value) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colorScheme.onSurface,
                  foregroundColor: context.colorScheme.surface,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Service', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
