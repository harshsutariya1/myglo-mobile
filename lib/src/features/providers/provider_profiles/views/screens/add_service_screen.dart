import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/app_logger.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/utils/network_error.dart';
import '../../../../../core/widgets/dashed_border.dart';
import '../../../../../core/widgets/snackbar_utils.dart';
import '../../../../../core/widgets/soon_badge.dart';
import '../../controllers/add_service_controller.dart';
import '../../models/service_catalog.dart';
import '../../models/service_model.dart';

enum _FormMode { create, edit, duplicate }

/// Create, edit or duplicate a service: one scrolling form with a sticky
/// save button.
class AddServiceScreen extends ConsumerStatefulWidget {
  const AddServiceScreen({super.key})
      : initial = null,
        _mode = _FormMode.create;

  /// Edits [service] in place.
  const AddServiceScreen.edit(ServiceModel service, {super.key})
      : initial = service,
        _mode = _FormMode.edit;

  /// Starts a new service prefilled from [service].
  const AddServiceScreen.duplicate(ServiceModel service, {super.key})
      : initial = service,
        _mode = _FormMode.duplicate;

  final ServiceModel? initial;
  final _FormMode _mode;

  @override
  ConsumerState<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends ConsumerState<AddServiceScreen> {
  static const double _pagePadding = 20;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _priceController;
  late final TextEditingController _customDurationController;
  late final TextEditingController _descriptionController;

  File? _newImage;
  String? _existingImageUrl;
  int? _durationMinutes;
  bool _customDuration = false;
  bool _showDurationError = false;
  bool _dirty = false;

  bool get _isEdit => widget._mode == _FormMode.edit;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final name = switch (widget._mode) {
      _FormMode.duplicate => _copyName(initial!.name),
      _ => initial?.name ?? '',
    };
    _nameController = TextEditingController(text: name);
    _categoryController = TextEditingController(text: initial?.category ?? '');
    _priceController = TextEditingController(text: initial == null ? '' : _priceText(initial.price));
    _descriptionController = TextEditingController(text: initial?.description ?? '');
    _existingImageUrl = initial?.imageUrl;
    _durationMinutes = initial?.durationMinutes;
    _customDuration = initial != null && !ServiceCatalog.durationPresets.contains(initial.durationMinutes);
    _customDurationController =
        TextEditingController(text: _customDuration ? '${initial!.durationMinutes}' : '');

    for (final controller in [
      _nameController,
      _categoryController,
      _priceController,
      _customDurationController,
      _descriptionController,
    ]) {
      controller.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _customDurationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  static String _copyName(String name) {
    final copy = '$name (copy)';
    return copy.length <= ServiceCatalog.maxNameLength ? copy : copy.substring(0, ServiceCatalog.maxNameLength);
  }

  static String _priceText(double price) =>
      price == price.roundToDouble() ? price.toStringAsFixed(0) : price.toStringAsFixed(2);

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      setState(() {
        _newImage = File(picked.path);
        _dirty = true;
      });
    } catch (e, st) {
      AppLogger.e('Service image picker failed', tag: 'AddService', error: e, stackTrace: st);
      if (mounted) context.showAppSnackBar("Couldn't open your photos. Check photo access in Settings.", isError: true);
    }
  }

  void _removeImage() {
    setState(() {
      _newImage = null;
      _existingImageUrl = null;
      _dirty = true;
    });
  }

  void _selectCategory(String category) {
    final selected = _categoryController.text.trim() == category;
    _categoryController.text = selected ? '' : category;
  }

  void _selectDuration(int? minutes, {bool custom = false}) {
    setState(() {
      _customDuration = custom;
      _durationMinutes = custom ? int.tryParse(_customDurationController.text.trim()) : minutes;
      _showDurationError = false;
      _dirty = true;
    });
  }

  /// Starts a "• " bullet on the line holding the cursor, or a new line if
  /// the current one already has text.
  void _insertBullet() {
    final text = _descriptionController.text;
    final selection = _descriptionController.selection;
    final cursor = selection.isValid ? selection.start : text.length;
    final lineStart = cursor == 0 ? 0 : text.lastIndexOf('\n', cursor - 1) + 1;
    final lineEnd = text.indexOf('\n', cursor);
    final line = text.substring(lineStart, lineEnd < 0 ? text.length : lineEnd);

    // The current line is already an empty bullet waiting for text.
    if (line.trim() == ServiceDescription.bullet.trim()) return;

    final String insert;
    final int at;
    if (line.trim().isEmpty) {
      insert = ServiceDescription.bullet;
      at = lineStart;
    } else if (line.trimLeft().startsWith(ServiceDescription.bullet.trim())) {
      insert = '\n${ServiceDescription.bullet}';
      at = lineEnd < 0 ? text.length : lineEnd;
    } else {
      insert = '${text.isEmpty ? '' : '\n'}${ServiceDescription.bullet}';
      at = lineEnd < 0 ? text.length : lineEnd;
    }
    final updated = text.replaceRange(at, at, insert);
    if (updated.length > ServiceCatalog.maxDescriptionLength) return;
    _descriptionController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: at + insert.length),
    );
  }

  String? _validatePrice(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter a price';
    final price = double.tryParse(text);
    if (price == null) return 'Enter a valid amount';
    if (price < 0) return "Price can't be negative";
    if (price > ServiceCatalog.maxPrice) return 'Max ${Formatters.aud(ServiceCatalog.maxPrice)}';
    return null;
  }

  String? _validateCustomDuration(String? value) {
    if (!_customDuration) return null;
    final minutes = int.tryParse(value?.trim() ?? '');
    if (minutes == null) return 'Enter minutes';
    if (minutes < ServiceCatalog.minDurationMinutes || minutes > ServiceCatalog.maxDurationMinutes) {
      return '${ServiceCatalog.minDurationMinutes}–${ServiceCatalog.maxDurationMinutes} min';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_customDuration) {
      _durationMinutes = int.tryParse(_customDurationController.text.trim());
    }
    final formValid = _formKey.currentState!.validate();
    final durationValid = _durationMinutes != null;
    if (!durationValid) setState(() => _showDurationError = true);
    if (!formValid || !durationValid) return;

    final name = _nameController.text.trim();
    final category = _categoryController.text.trim();
    final description = _descriptionController.text.trim();
    final price = double.parse(_priceController.text.trim());
    final controller = ref.read(addServiceControllerProvider.notifier);

    final success = _isEdit
        ? await controller.updateService(
            original: widget.initial!,
            name: name,
            description: description,
            price: price,
            durationMinutes: _durationMinutes!,
            category: category.isEmpty ? null : category,
            newImage: _newImage,
            removeImage: _newImage == null && _existingImageUrl == null,
          )
        : await controller.addService(
            name: name,
            description: description,
            price: price,
            durationMinutes: _durationMinutes!,
            category: category.isEmpty ? null : category,
            imageFile: _newImage,
            existingImageUrl: _newImage == null ? _existingImageUrl : null,
          );

    if (!mounted) return;
    if (success) {
      _dirty = false;
      context.showAppSnackBar(_isEdit ? 'Service updated' : 'Service published');
      Navigator.of(context).pop();
    } else {
      final error = ref.read(addServiceControllerProvider).error;
      final offline = error != null && isConnectivityError(error);
      context.showAppSnackBar(
        offline
            ? "You're offline. Your service wasn't saved. Try again when you're connected."
            : "Couldn't save your service. Please try again.",
        isError: true,
      );
    }
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text("Your changes to this service haven't been saved."),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep editing')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.destructive),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final isSaving = ref.watch(addServiceControllerProvider).isLoading;
    final title = switch (widget._mode) {
      _FormMode.create => 'New service',
      _FormMode.edit => 'Edit service',
      _FormMode.duplicate => 'Duplicate service',
    };

    return PopScope(
      canPop: !_dirty && !isSaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || isSaving) return;
        if (await _confirmDiscard() && context.mounted) {
          _dirty = false;
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          title: Text(title),
          centerTitle: true,
          scrolledUnderElevation: 0.5,
          surfaceTintColor: Colors.transparent,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(_pagePadding, 8, _pagePadding, 32),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              _CoverPicker(
                newImage: _newImage,
                existingUrl: _existingImageUrl,
                onPick: isSaving ? null : _pickImage,
                onRemove: isSaving ? null : _removeImage,
              ),
              const _SectionLabel('Basics'),
              TextFormField(
                controller: _nameController,
                enabled: !isSaving,
                textCapitalization: TextCapitalization.sentences,
                maxLength: ServiceCatalog.maxNameLength,
                decoration: _inputDecoration(context, label: 'Service title', hint: 'e.g. Balayage & toner'),
                validator: (value) => (value?.trim().isEmpty ?? true) ? 'Give your service a title' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _categoryController,
                enabled: !isSaving,
                textCapitalization: TextCapitalization.words,
                maxLength: ServiceCatalog.maxCategoryLength,
                decoration: _inputDecoration(context, label: 'Category (optional)', hint: 'Pick one below or type your own'),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _categoryController,
                builder: (context, value, _) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in ServiceCatalog.categorySuggestions)
                      _ChoicePill(
                        label: category,
                        selected: value.text.trim() == category,
                        onTap: isSaving ? null : () => _selectCategory(category),
                      ),
                  ],
                ),
              ),
              const _SectionLabel('Price & duration'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      enabled: !isSaving,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,5}(\.\d{0,2})?'))],
                      decoration: _inputDecoration(context, label: 'Price', prefixText: r'$ ', suffixText: 'AUD'),
                      validator: _validatePrice,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SoonToggle(
                      label: 'Show discount',
                      onTap: () => context.showComingSoon('Discounted pricing'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Duration',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: scheme.onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final minutes in ServiceCatalog.durationPresets)
                    _ChoicePill(
                      label: Formatters.duration(minutes),
                      selected: !_customDuration && _durationMinutes == minutes,
                      onTap: isSaving ? null : () => _selectDuration(minutes),
                    ),
                  _ChoicePill(
                    label: 'Custom',
                    icon: Icons.tune_rounded,
                    selected: _customDuration,
                    onTap: isSaving ? null : () => _selectDuration(null, custom: true),
                  ),
                ],
              ),
              if (_customDuration) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: _customDurationController,
                    enabled: !isSaving,
                    autofocus: widget.initial == null,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                    decoration: _inputDecoration(context, label: 'Minutes', suffixText: 'min'),
                    validator: _validateCustomDuration,
                    onChanged: (value) => _durationMinutes = int.tryParse(value.trim()),
                  ),
                ),
              ],
              if (_showDurationError) ...[
                const SizedBox(height: 8),
                Text('Choose how long the service takes',
                    style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.error)),
              ],
              const _SectionLabel('Where it happens', soon: true),
              _LocationModePreview(onTap: () => context.showComingSoon('Mobile and online services')),
              const _SectionLabel("Description & what's included"),
              TextFormField(
                controller: _descriptionController,
                enabled: !isSaving,
                minLines: 5,
                maxLines: 12,
                maxLength: ServiceCatalog.maxDescriptionLength,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                decoration: _inputDecoration(
                  context,
                  label: 'Description',
                  hint: 'Describe the service, then list what\'s included:\n• Consultation\n• Wash & treatment\n• Blow-dry',
                  alignLabelWithHint: true,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: isSaving ? null : _insertBullet,
                  icon: const Icon(Icons.format_list_bulleted_rounded, size: 18),
                  label: const Text('Add included item'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.secondary,
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              Text(
                'Bullet lines appear as a checklist when clients view the service.',
                style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _StickySaveBar(
          label: _isEdit ? 'Save changes' : 'Save & publish service',
          saving: isSaving,
          onPressed: _submit,
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  String? prefixText,
  String? suffixText,
  bool alignLabelWithHint = false,
}) {
  final scheme = context.colorScheme;
  final radius = BorderRadius.circular(14);
  return InputDecoration(
    labelText: label,
    hintText: hint,
    hintMaxLines: 4,
    prefixText: prefixText,
    suffixText: suffixText,
    alignLabelWithHint: alignLabelWithHint,
    filled: true,
    fillColor: scheme.onSurface.withValues(alpha: 0.03),
    border: OutlineInputBorder(borderRadius: radius),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: scheme.onSurface.withValues(alpha: 0.1)),
    ),
    focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.primary, width: 1.5)),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.soon = false});

  final String label;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Row(
        children: [
          Flexible(
            child: Semantics(
              header: true,
              child: Text(
                label,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.colorScheme.onSurface),
              ),
            ),
          ),
          if (soon) ...[const SizedBox(width: 8), const SoonBadge()],
        ],
      ),
    );
  }
}

/// Dashed drop target until a photo is chosen, then a cover preview.
class _CoverPicker extends StatelessWidget {
  const _CoverPicker({required this.newImage, required this.existingUrl, required this.onPick, required this.onRemove});

  static const double _height = 190;

  final File? newImage;
  final String? existingUrl;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final ImageProvider? image = newImage != null
        ? FileImage(newImage!)
        : existingUrl != null
            ? CachedNetworkImageProvider(existingUrl!)
            : null;

    if (image == null) {
      return Semantics(
        button: true,
        label: 'Add a cover photo',
        child: InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(18),
          child: DashedBorder(
            color: scheme.onSurface.withValues(alpha: 0.25),
            radius: 18,
            child: SizedBox(
              height: _height,
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(Icons.add_photo_alternate_outlined, color: scheme.secondary, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text('Add a cover photo',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface)),
                  const SizedBox(height: 4),
                  Text('Show clients the finished result',
                      style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.55))),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: _height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(image: image, fit: BoxFit.cover),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(999)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Cover', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Row(
                    children: [
                      _OverlayIconButton(icon: Icons.edit_outlined, tooltip: 'Change cover photo', onPressed: onPick),
                      const SizedBox(width: 8),
                      _OverlayIconButton(icon: Icons.delete_outline_rounded, tooltip: 'Remove cover photo', onPressed: onRemove),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => context.showComingSoon('Multiple service photos'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(Icons.collections_outlined, size: 18, color: scheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Text('Add more photos',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: scheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(width: 8),
                const SoonBadge(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.55)),
        icon: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final foreground = selected ? scheme.surface : scheme.onSurface.withValues(alpha: 0.8);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? scheme.onSurface : scheme.surface,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.14)),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 15, color: foreground), const SizedBox(width: 6)],
                Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: foreground)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Discount toggle placeholder sized to sit beside the price field.
class _SoonToggle extends StatelessWidget {
  const _SoonToggle({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.onSurface.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: scheme.onSurface.withValues(alpha: 0.5))),
                  const SizedBox(height: 3),
                  const SoonBadge(),
                ],
              ),
            ),
            IgnorePointer(
              child: Switch(value: false, onChanged: null, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented control previewing location modes. Every service is currently
/// delivered at the provider's address.
class _LocationModePreview extends StatelessWidget {
  const _LocationModePreview({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: IgnorePointer(
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('My place'), icon: Icon(Icons.storefront_outlined, size: 18)),
              ButtonSegment(value: 1, label: Text("Client's"), icon: Icon(Icons.home_outlined, size: 18)),
              ButtonSegment(value: 2, label: Text('Online'), icon: Icon(Icons.videocam_outlined, size: 18)),
            ],
            selected: const {0},
            onSelectionChanged: null,
          ),
        ),
      ),
    );
  }
}

class _StickySaveBar extends StatelessWidget {
  const _StickySaveBar({required this.label, required this.saving, required this.onPressed});

  final String label;
  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08))),
      ),
      child: SizedBox(
        height: 52,
        child: FilledButton(
          onPressed: saving ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.onSurface,
            foregroundColor: scheme.surface,
            disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.6),
            disabledForegroundColor: scheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          child: saving
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.surface)),
                    const SizedBox(width: 12),
                    const Text('Saving…'),
                  ],
                )
              : Text(label),
        ),
      ),
    );
  }
}
