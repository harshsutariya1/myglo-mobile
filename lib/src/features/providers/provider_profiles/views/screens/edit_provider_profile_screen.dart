import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/config/app_config.dart';
import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/app_logger.dart';
import '../../../../../core/utils/network_error.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../../core/widgets/snackbar_utils.dart';
import '../../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../../shared/authentication/models/profile_model.dart';
import '../../controllers/edit_provider_profile_controller.dart';
import '../widgets/profile_pic_picker.dart';
import '../widgets/settings_widgets.dart';

/// Everything clients see about a provider, in one place: photo, cover
/// photos, business name, bio, location and contact number, plus the
/// owner's own name. Who can see the email and phone is set in Settings.
class EditProviderProfileScreen extends ConsumerStatefulWidget {
  const EditProviderProfileScreen({super.key});

  @override
  ConsumerState<EditProviderProfileScreen> createState() => _EditProviderProfileScreenState();
}

class _EditProviderProfileScreenState extends ConsumerState<EditProviderProfileScreen> {
  static const int _nameMax = 100;
  static const int _businessNameMax = 80;
  static const int _bioMax = 500;

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _businessName = TextEditingController();
  final _phone = TextEditingController();
  final _bio = TextEditingController();

  File? _newProfilePic;
  bool _loaded = false;

  /// What was last saved, to tell whether anything changed.
  late Map<String, String> _initial;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _businessName.dispose();
    _phone.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _load(ProfileModel profile) {
    _firstName.text = profile.firstName ?? '';
    _lastName.text = profile.lastName ?? '';
    _businessName.text = profile.providerName ?? '';
    _phone.text = profile.phoneNumber ?? '';
    _bio.text = profile.bio ?? '';
    _initial = _values;
    _loaded = true;
  }

  Map<String, String> get _values => {
        'first': _firstName.text.trim(),
        'last': _lastName.text.trim(),
        'business': _businessName.text.trim(),
        'phone': _phone.text.trim(),
        'bio': _bio.text.trim(),
      };

  bool get _dirty {
    if (!_loaded) return false;
    if (_newProfilePic != null) return true;
    final values = _values;
    return values.keys.any((key) => values[key] != _initial[key]);
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 90);
      if (picked != null && mounted) setState(() => _newProfilePic = File(picked.path));
    } on PlatformException catch (e, st) {
      AppLogger.w('Picking a profile photo failed', tag: 'EditProviderProfile', error: e, stackTrace: st);
      if (mounted) context.showAppSnackBar('Allow photo access in Settings to choose a photo.', isError: true);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = ref.read(userProfileProvider).value;
    if (user == null) return;

    final saved = await ref.read(editProviderProfileControllerProvider.notifier).saveProfile(
          id: user.rawUser.id,
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          providerName: _businessName.text.trim(),
          phone: _phone.text.trim(),
          bio: _bio.text.trim(),
          newProfilePic: _newProfilePic,
        );
    if (!mounted) return;
    if (saved) {
      HapticFeedback.mediumImpact();
      setState(() {
        _initial = _values;
        _newProfilePic = null;
      });
      context.showAppSnackBar('Profile updated');
      context.pop();
    } else {
      final error = ref.read(editProviderProfileControllerProvider).error;
      context.showAppSnackBar(
        error != null && isConnectivityError(error)
            ? "You're offline, so your changes weren't saved. Check your connection and try again."
            : "We couldn't save your profile. Please try again.",
        isError: true,
      );
    }
  }

  Future<void> _confirmLeave() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text("Your edits haven't been saved."),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep editing')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Discard')),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() {
        _initial = _values;
        _newProfilePic = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop();
      });
    }
  }

  static String? _required(String? value, String label, {int max = _nameMax}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label is required';
    if (text.length > max) return '$label must be $max characters or fewer';
    return null;
  }

  static String? _validatePhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^[+\d][\d\s()-]*$').hasMatch(text) || digits.length < 8 || digits.length > 15) {
      return 'Enter a valid phone number, e.g. 0412 345 678';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final user = ref.watch(userProfileProvider).value;
    final saving = ref.watch(editProviderProfileControllerProvider).isLoading;
    final profile = user?.profile;
    if (!_loaded && profile != null) _load(profile);

    return PopScope(
      canPop: !_dirty || saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !saving) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: settingsBackground(context),
        appBar: AppBar(
          title: const Text('Edit profile'),
          centerTitle: true,
          backgroundColor: settingsBackground(context),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0.5,
        ),
        body: profile == null
            ? const FormSkeleton()
            : Form(
                key: _formKey,
                onChanged: () => setState(() {}),
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          ProfilePicPicker(
                            newProfilePic: _newProfilePic,
                            existingProfilePicUrl: profile.profilePic,
                            onPickImage: _pickPhoto,
                          ),
                          TextButton(
                            onPressed: _pickPhoto,
                            style: TextButton.styleFrom(
                              foregroundColor: scheme.secondary,
                              textStyle: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            child: Text(profile.profilePic == null && _newProfilePic == null ? 'Add photo' : 'Change photo'),
                          ),
                        ],
                      ),
                    ),
                    _CoverPhotosStrip(photos: profile.coverPhotos),
                    SettingsSection(
                      title: 'Business',
                      showDividers: false,
                      children: [
                        _FieldRow(
                          child: TextFormField(
                            controller: _businessName,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            maxLength: _businessNameMax,
                            decoration: _decoration(context, 'Business or salon name', Icons.storefront_outlined),
                            validator: (value) => _required(value, 'Business name', max: _businessNameMax),
                          ),
                        ),
                        _FieldRow(
                          child: TextFormField(
                            controller: _bio,
                            minLines: 3,
                            maxLines: 6,
                            maxLength: _bioMax,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: _decoration(context, 'Bio', null).copyWith(
                              hintText: 'What you specialise in, your experience, what clients can expect',
                              alignLabelWithHint: true,
                            ),
                          ),
                        ),
                        SettingsTile(
                          icon: Icons.place_outlined,
                          title: 'Studio location',
                          subtitle: (profile.addressText?.trim().isNotEmpty ?? false)
                              ? profile.addressText!.trim()
                              : 'Not set. Clients find you on the map once you add it',
                          iconColor: profile.coordinates == null ? AppTheme.warning : null,
                          onTap: () => context.pushNamed(AppRoute.businessLocation.name),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Your details',
                      showDividers: false,
                      children: [
                        _FieldRow(
                          child: TextFormField(
                            controller: _firstName,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.givenName],
                            decoration: _decoration(context, 'First name', Icons.person_outline_rounded),
                            validator: (value) => _required(value, 'First name'),
                          ),
                        ),
                        _FieldRow(
                          child: TextFormField(
                            controller: _lastName,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.familyName],
                            decoration: _decoration(context, 'Last name', Icons.person_outline_rounded),
                            validator: (value) => _required(value, 'Last name'),
                          ),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Contact',
                      showDividers: false,
                      footer: 'Choose whether clients see your email and phone in Settings › Privacy.',
                      children: [
                        _FieldRow(
                          child: TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            autofillHints: const [AutofillHints.telephoneNumber],
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[\d+\s()-]')),
                              LengthLimitingTextInputFormatter(20),
                            ],
                            decoration: _decoration(context, 'Phone number', Icons.phone_outlined),
                            validator: _validatePhone,
                          ),
                        ),
                        SettingsTile(
                          icon: Icons.alternate_email_rounded,
                          title: 'Email',
                          subtitle: user?.rawUser.email ?? profile.email ?? 'Not set',
                          trailing: Icon(Icons.lock_outline_rounded, size: 18, color: scheme.onSurface.withValues(alpha: 0.35)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: profile == null
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton(
                  onPressed: saving || !_dirty ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.onSurface,
                    foregroundColor: scheme.surface,
                    minimumSize: const Size(0, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  child: saving
                      ? SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.surface))
                      : Text(_dirty ? 'Save changes' : 'No changes'),
                ),
              ),
      ),
    );
  }

  static InputDecoration _decoration(BuildContext context, String label, IconData? icon) {
    final scheme = context.colorScheme;
    return InputDecoration(
      labelText: label,
      counterText: '',
      prefixIcon: icon == null ? null : Icon(icon, size: 20, color: scheme.secondary),
      filled: true,
      fillColor: scheme.onSurface.withValues(alpha: 0.03),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.destructive),
      ),
    );
  }
}

/// A form field inside a settings card, padded like a tile.
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 12), child: child);
}

/// The provider's cover photos at a glance, with a way to manage them.
class _CoverPhotosStrip extends StatelessWidget {
  const _CoverPhotosStrip({required this.photos});

  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SettingsSection(
      title: 'Cover photos',
      children: [
        InkWell(
          onTap: () => context.pushNamed(AppRoute.coverPhotos.name),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 72,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < AppConfig.coverPhotosMax; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: i < photos.length
                                ? CachedNetworkImage(
                                    imageUrl: photos[i],
                                    fit: BoxFit.cover,
                                    memCacheWidth: 240,
                                    placeholder: (_, _) => const Shimmer(child: SkeletonBox(borderRadius: 0)),
                                    errorWidget: (_, _, _) => ColoredBox(color: scheme.onSurface.withValues(alpha: 0.06)),
                                  )
                                : ColoredBox(
                                    color: scheme.primary.withValues(alpha: 0.06),
                                    child: Icon(Icons.add_rounded, color: scheme.primary.withValues(alpha: 0.5)),
                                  ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        photos.isEmpty
                            ? 'Add photos of your space and work'
                            : '${photos.length} of ${AppConfig.coverPhotosMax} photos · first is your main cover',
                        style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ),
                    Text(
                      'Manage',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: scheme.secondary),
                    ),
                    Icon(Icons.chevron_right_rounded, color: scheme.secondary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
