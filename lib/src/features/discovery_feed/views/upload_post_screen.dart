import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/network_error.dart';
import '../../../core/widgets/dashed_border.dart';
import '../../../core/widgets/skeleton/skeletons.dart';
import '../../../core/widgets/snackbar_utils.dart';
import '../../../core/widgets/soon_badge.dart';
import '../../providers/provider_profiles/models/service_model.dart';
import '../../shared/authentication/controllers/user_profile_provider.dart';
import '../../shared/services/views/widgets/service_tile.dart';
import '../controllers/upload_post_controller.dart';
import '../models/post_repository.dart';
import 'widgets/provider_search_bottom_sheet.dart';

/// Crop applied to every photo in the post.
enum PostAspect {
  square(1, '1:1', Icons.crop_square_rounded),
  portrait(4 / 5, '4:5', Icons.crop_portrait_rounded),
  landscape(16 / 9, '16:9', Icons.crop_landscape_rounded);

  const PostAspect(this.ratio, this.label, this.icon);

  final double ratio;
  final String label;
  final IconData icon;
}

/// Media-first post composer: pick and order photos, choose a crop, write a
/// caption and link the service the photos show.
class UploadPostScreen extends ConsumerStatefulWidget {
  const UploadPostScreen({super.key});

  @override
  ConsumerState<UploadPostScreen> createState() => _UploadPostScreenState();
}

class _UploadPostScreenState extends ConsumerState<UploadPostScreen> {
  static const double _pagePadding = 20;
  static final RegExp _mentionAtCursor = RegExp(r'(?:^|\s)@(\w{2,})$');

  final _captionController = TextEditingController();
  final _picker = ImagePicker();
  final List<File> _images = [];
  int _previewIndex = 0;
  PostAspect _aspect = PostAspect.portrait;

  ProviderSearchResult? _selectedProvider;
  ServiceModel? _selectedService;
  List<ServiceModel> _services = const [];
  bool _loadingServices = false;
  bool _servicesFailed = false;

  Timer? _mentionDebounce;
  String? _mentionQuery;
  List<ProviderSearchResult> _mentionResults = const [];

  (int, int)? _progress;
  bool _hasCaption = false;
  bool _requestedOwnServices = false;

  bool get _isProvider => ref.read(userProfileProvider).value?.isProvider ?? false;
  bool get _hasDraft => _images.isNotEmpty || _hasCaption;

  @override
  void initState() {
    super.initState();
    _captionController.addListener(_onCaptionChanged);
    // Providers link their own services; load them as soon as the profile is
    // known (it may still be resolving when the screen opens).
    ref.listenManual(userProfileProvider, (_, next) {
      final profile = next.value;
      if (!_requestedOwnServices && profile != null && profile.isProvider) {
        _requestedOwnServices = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fetchServices(profile.rawUser.id);
        });
      }
    }, fireImmediately: true);
    // Media first: go straight to the gallery.
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickImages());
  }

  @override
  void dispose() {
    _mentionDebounce?.cancel();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = AppConfig.postMaxMedia - _images.length;
    if (remaining <= 0) {
      context.showAppSnackBar('A post can have up to ${AppConfig.postMaxMedia} photos');
      return;
    }
    try {
      // `limit` must be at least 2, so a single free slot uses the single picker.
      final picked = remaining == 1
          ? [?await _picker.pickImage(source: ImageSource.gallery)]
          : await _picker.pickMultiImage(limit: remaining);
      if (picked.isEmpty || !mounted) return;
      setState(() {
        final firstNew = _images.length;
        _images.addAll(picked.take(remaining).map((file) => File(file.path)));
        _previewIndex = firstNew;
      });
    } catch (e, st) {
      AppLogger.e('Post image picker failed', tag: 'UploadPost', error: e, stackTrace: st);
      if (mounted) context.showAppSnackBar("Couldn't open your photos. Check photo access in Settings.", isError: true);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      if (_previewIndex >= _images.length) _previewIndex = (_images.length - 1).clamp(0, AppConfig.postMaxMedia);
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final previewed = _images[_previewIndex];
      _images.insert(newIndex, _images.removeAt(oldIndex));
      _previewIndex = _images.indexOf(previewed);
    });
  }

  Future<void> _fetchServices(String providerId) async {
    setState(() {
      _loadingServices = true;
      _servicesFailed = false;
      _selectedService = null;
    });
    try {
      final services = await ref.read(postRepositoryProvider).getProviderServices(providerId);
      if (mounted) setState(() => _services = services);
    } catch (_) {
      // Reported by the repository; offer a retry instead.
      if (mounted) setState(() => _servicesFailed = true);
    } finally {
      if (mounted) setState(() => _loadingServices = false);
    }
  }

  void _onCaptionChanged() {
    // Rebuild when the caption becomes (non-)empty so the back-navigation
    // guard knows whether there is a draft to lose.
    final hasCaption = _captionController.text.trim().isNotEmpty;
    if (hasCaption != _hasCaption) setState(() => _hasCaption = hasCaption);

    final selection = _captionController.selection;
    final text = _captionController.text;
    final cursor = selection.isValid ? selection.baseOffset : text.length;
    final match = _mentionAtCursor.firstMatch(text.substring(0, cursor.clamp(0, text.length)));
    final query = match?.group(1);
    if (query == _mentionQuery) return;

    _mentionQuery = query;
    _mentionDebounce?.cancel();
    if (query == null) {
      if (_mentionResults.isNotEmpty) setState(() => _mentionResults = const []);
      return;
    }
    _mentionDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await ref.read(postRepositoryProvider).searchProviders(query);
        if (mounted && _mentionQuery == query) setState(() => _mentionResults = results.take(5).toList());
      } catch (_) {
        // Suggestions are a convenience; typing still works without them.
      }
    });
  }

  void _insertMention(ProviderSearchResult provider) {
    final text = _captionController.text;
    final cursor = _captionController.selection.isValid ? _captionController.selection.baseOffset : text.length;
    if (cursor <= 0) return;
    final start = text.lastIndexOf('@', cursor - 1);
    if (start < 0) return;
    final handle = provider.providerName.replaceAll(RegExp(r'[^\w]'), '');
    final insert = '@$handle ';
    final updated = text.replaceRange(start, cursor, insert);
    if (updated.length > AppConfig.postCaptionMaxLength) return;
    _mentionQuery = null;
    _captionController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
    setState(() => _mentionResults = const []);
  }

  Future<void> _chooseService() async {
    final chosen = await showModalBottomSheet<ServiceModel>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: context.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Link a service',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.colorScheme.onSurface),
              ),
            ),
            for (final service in _services)
              ServiceTile(
                service: service,
                onTap: () => Navigator.of(sheetContext).pop(service),
                trailing: service.id == _selectedService?.id
                    ? const SizedBox.square(
                        dimension: ServiceTileMetrics.actionSize,
                        child: Icon(Icons.check_circle_rounded, color: AppTheme.success),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) setState(() => _selectedService = chosen);
  }

  Future<void> _publish() async {
    if (_images.isEmpty) {
      context.showAppSnackBar('Add at least one photo');
      return;
    }
    final userProfile = ref.read(userProfileProvider).value;
    if (userProfile == null) return;
    FocusScope.of(context).unfocus();

    final success = await ref.read(uploadPostControllerProvider.notifier).uploadPost(
          authorId: userProfile.rawUser.id,
          images: List.of(_images),
          caption: _captionController.text.trim(),
          taggedProviderId: userProfile.isProvider ? null : _selectedProvider?.id,
          serviceId: _selectedService?.id,
          aspectRatio: _aspect.ratio,
          onProgress: (done, total) {
            if (mounted) setState(() => _progress = (done, total));
          },
        );

    if (!mounted) return;
    setState(() => _progress = null);
    if (success) {
      _images.clear();
      _captionController.clear();
      context.showAppSnackBar('Post published');
      Navigator.of(context).pop();
    } else {
      final error = ref.read(uploadPostControllerProvider).error;
      final offline = error != null && isConnectivityError(error);
      context.showAppSnackBar(
        offline
            ? "You're offline. Your post wasn't published. Try again when you're connected."
            : "Couldn't publish your post. Please try again.",
        isError: true,
      );
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard this post?'),
        content: const Text("Your photos and caption won't be saved."),
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
    if (discard == true && mounted) {
      _images.clear();
      _captionController.clear();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final uploading = ref.watch(uploadPostControllerProvider).isLoading;
    final userProfile = ref.watch(userProfileProvider).value;
    final isProvider = userProfile?.isProvider ?? false;

    return PopScope(
      canPop: !uploading && !_hasDraft,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !uploading) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          title: const Text('New post'),
          centerTitle: true,
          scrolledUnderElevation: 0.5,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(Icons.close_rounded),
            onPressed: uploading ? null : () => Navigator.of(context).maybePop(),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: uploading || _images.isEmpty ? null : _publish,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.secondary,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                child: const Text('Share'),
              ),
            ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: uploading,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              if (_images.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(_pagePadding, 8, _pagePadding, 0),
                  child: _EmptyCanvas(onTap: _pickImages),
                )
              else ...[
                _Preview(image: _images[_previewIndex], aspect: _aspect),
                const SizedBox(height: 12),
                _AspectToggle(
                  value: _aspect,
                  onChanged: (aspect) => setState(() => _aspect = aspect),
                ),
                const SizedBox(height: 12),
                _ThumbnailStrip(
                  images: _images,
                  previewIndex: _previewIndex,
                  onSelect: (index) => setState(() => _previewIndex = index),
                  onRemove: _removeImage,
                  onReorder: _reorder,
                  onAdd: _images.length < AppConfig.postMaxMedia ? _pickImages : null,
                ),
              ],
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionLabel('Caption'),
                    TextField(
                      controller: _captionController,
                      minLines: 3,
                      maxLines: 8,
                      maxLength: AppConfig.postCaptionMaxLength,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _fieldDecoration(context, hint: 'Describe the look… use #tags and @mention providers'),
                    ),
                    if (_mentionResults.isNotEmpty) _MentionSuggestions(results: _mentionResults, onSelect: _insertMention),
                    if (!isProvider) ...[
                      const _SectionLabel('Tag a provider'),
                      _TaggedProviderField(
                        provider: _selectedProvider,
                        onSearch: () async {
                          final selected = await ProviderSearchBottomSheet.show(context);
                          if (selected == null || !mounted) return;
                          setState(() {
                            _selectedProvider = selected;
                            _selectedService = null;
                            _services = const [];
                          });
                          _fetchServices(selected.id);
                        },
                        onClear: () => setState(() {
                          _selectedProvider = null;
                          _selectedService = null;
                          _services = const [];
                        }),
                      ),
                    ],
                    if (isProvider || _selectedProvider != null) ...[
                      const _SectionLabel('Link a service'),
                      _LinkedServiceField(
                        loading: _loadingServices,
                        failed: _servicesFailed,
                        services: _services,
                        selected: _selectedService,
                        emptyMessage: isProvider
                            ? 'Add a service first to link it to your posts.'
                            : "This provider hasn't listed any services yet.",
                        onRetry: () {
                          final id = _isProvider ? userProfile?.rawUser.id : _selectedProvider?.id;
                          if (id != null) _fetchServices(id);
                        },
                        onChoose: _chooseService,
                        onClear: () => setState(() => _selectedService = null),
                      ),
                    ],
                    const _SectionLabel('Location', soon: true),
                    _SoonRow(
                      icon: Icons.place_outlined,
                      label: 'Add a suburb or neighbourhood',
                      onTap: () => context.showComingSoon('Location tags'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _PublishBar(
          enabled: _images.isNotEmpty,
          progress: uploading ? _progress : null,
          uploading: uploading,
          onPressed: _publish,
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(BuildContext context, {required String hint}) {
  final scheme = context.colorScheme;
  final radius = BorderRadius.circular(14);
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: scheme.onSurface.withValues(alpha: 0.03),
    border: OutlineInputBorder(borderRadius: radius),
    enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.onSurface.withValues(alpha: 0.1))),
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
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Row(
        children: [
          Flexible(
            child: Semantics(
              header: true,
              child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.colorScheme.onSurface)),
            ),
          ),
          if (soon) ...[const SizedBox(width: 8), const SoonBadge()],
        ],
      ),
    );
  }
}

class _EmptyCanvas extends StatelessWidget {
  const _EmptyCanvas({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Semantics(
      button: true,
      label: 'Choose photos',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: DashedBorder(
          color: scheme.onSurface.withValues(alpha: 0.25),
          radius: 20,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(Icons.add_photo_alternate_outlined, size: 32, color: scheme.secondary),
                ),
                const SizedBox(height: 14),
                Text('Choose photos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurface)),
                const SizedBox(height: 4),
                Text(
                  'Up to ${AppConfig.postMaxMedia} · shown in the order you pick them',
                  style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.55)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The selected photo framed at the chosen crop, as it will be published.
class _Preview extends StatelessWidget {
  const _Preview({required this.image, required this.aspect});

  final File image;
  final PostAspect aspect;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.5;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ColoredBox(
        color: context.colorScheme.onSurface.withValues(alpha: 0.04),
        child: Center(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: AspectRatio(
              aspectRatio: aspect.ratio,
              child: Image.file(image, fit: BoxFit.cover, gaplessPlayback: true),
            ),
          ),
        ),
      ),
    );
  }
}

class _AspectToggle extends StatelessWidget {
  const _AspectToggle({required this.value, required this.onChanged});

  final PostAspect value;
  final ValueChanged<PostAspect> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SegmentedButton<PostAspect>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact),
        segments: [
          for (final aspect in PostAspect.values)
            ButtonSegment(value: aspect, label: Text(aspect.label), icon: Icon(aspect.icon, size: 18)),
        ],
        selected: {value},
        onSelectionChanged: (selection) => onChanged(selection.single),
      ),
    );
  }
}

/// Selected photos in carousel order. Long-press and drag to reorder.
class _ThumbnailStrip extends StatelessWidget {
  const _ThumbnailStrip({
    required this.images,
    required this.previewIndex,
    required this.onSelect,
    required this.onRemove,
    required this.onReorder,
    required this.onAdd,
  });

  static const double _size = 76;

  final List<File> images;
  final int previewIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onRemove;
  final ReorderCallback onReorder;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SizedBox(
      height: _size + 8,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        buildDefaultDragHandles: false,
        itemCount: images.length,
        onReorder: onReorder,
        proxyDecorator: (child, _, _) => Material(color: Colors.transparent, child: child),
        footer: onAdd == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(12),
                  child: DashedBorder(
                    color: scheme.onSurface.withValues(alpha: 0.25),
                    radius: 12,
                    child: SizedBox.square(
                      dimension: _size,
                      child: Icon(Icons.add_rounded, color: scheme.onSurface.withValues(alpha: 0.6), semanticLabel: 'Add photos'),
                    ),
                  ),
                ),
              ),
        itemBuilder: (context, index) {
          final selected = index == previewIndex;
          return ReorderableDelayedDragStartListener(
            key: ObjectKey(images[index]),
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, right: 8),
              child: Semantics(
                button: true,
                selected: selected,
                label: 'Photo ${index + 1}. Long press to reorder.',
                child: GestureDetector(
                  onTap: () => onSelect(index),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: _size,
                        height: _size,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: selected ? scheme.secondary : Colors.transparent, width: 2),
                          image: DecorationImage(image: ResizeImage(FileImage(images[index]), width: 220), fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? scheme.secondary : Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: SizedBox.square(
                          dimension: 32,
                          child: IconButton(
                            tooltip: 'Remove photo ${index + 1}',
                            padding: EdgeInsets.zero,
                            onPressed: () => onRemove(index),
                            icon: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(color: scheme.onSurface, shape: BoxShape.circle),
                              child: Icon(Icons.close_rounded, size: 13, color: scheme.surface),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MentionSuggestions extends StatelessWidget {
  const _MentionSuggestions({required this.results, required this.onSelect});

  final List<ProviderSearchResult> results;
  final ValueChanged<ProviderSearchResult> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          for (final result in results)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: scheme.primary.withValues(alpha: 0.2),
                backgroundImage: result.profilePic != null ? CachedNetworkImageProvider(result.profilePic!) : null,
                child: result.profilePic == null ? Icon(Icons.storefront_outlined, size: 16, color: scheme.secondary) : null,
              ),
              title: Text(result.providerName, style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => onSelect(result),
            ),
        ],
      ),
    );
  }
}

class _TaggedProviderField extends StatelessWidget {
  const _TaggedProviderField({required this.provider, required this.onSearch, required this.onClear});

  final ProviderSearchResult? provider;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final selected = provider;
    return _OutlinedRow(
      onTap: selected == null ? onSearch : null,
      leading: selected == null
          ? Icon(Icons.search_rounded, color: scheme.onSurface.withValues(alpha: 0.5))
          : CircleAvatar(
              radius: 18,
              backgroundColor: scheme.primary.withValues(alpha: 0.2),
              backgroundImage: selected.profilePic != null ? CachedNetworkImageProvider(selected.profilePic!) : null,
              child: selected.profilePic == null ? Icon(Icons.storefront_outlined, size: 18, color: scheme.secondary) : null,
            ),
      title: selected?.providerName ?? 'Search for the provider who did this',
      muted: selected == null,
      trailing: selected == null
          ? null
          : IconButton(tooltip: 'Remove provider', icon: const Icon(Icons.close_rounded), onPressed: onClear),
    );
  }
}

class _LinkedServiceField extends StatelessWidget {
  const _LinkedServiceField({
    required this.loading,
    required this.failed,
    required this.services,
    required this.selected,
    required this.emptyMessage,
    required this.onRetry,
    required this.onChoose,
    required this.onClear,
  });

  final bool loading;
  final bool failed;
  final List<ServiceModel> services;
  final ServiceModel? selected;
  final String emptyMessage;
  final VoidCallback onRetry;
  final VoidCallback onChoose;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    if (loading) return const Shimmer(child: SkeletonBox(height: 64, borderRadius: 14));
    if (failed) {
      return _OutlinedRow(
        leading: Icon(Icons.cloud_off_outlined, color: scheme.secondary),
        title: "Services didn't load",
        muted: true,
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
      );
    }
    if (services.isEmpty) {
      return Text(emptyMessage, style: TextStyle(fontSize: 13.5, color: scheme.onSurface.withValues(alpha: 0.55)));
    }
    final service = selected;
    if (service == null) {
      return _OutlinedRow(
        onTap: onChoose,
        leading: Icon(Icons.link_rounded, color: scheme.secondary),
        title: 'Choose the service shown',
        subtitle: 'Clients can book it straight from your post',
        trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withValues(alpha: 0.4)),
      );
    }
    return _OutlinedRow(
      onTap: onChoose,
      leading: ServiceThumbnail(imageUrl: service.imageUrl, size: 40, radius: 8),
      title: service.name,
      subtitle: '${Formatters.aud(service.price)} · ${Formatters.duration(service.durationMinutes)}',
      trailing: IconButton(tooltip: 'Unlink service', icon: const Icon(Icons.close_rounded), onPressed: onClear),
    );
  }
}

class _SoonRow extends StatelessWidget {
  const _SoonRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _OutlinedRow(
      onTap: onTap,
      leading: Icon(icon, color: context.colorScheme.onSurface.withValues(alpha: 0.45)),
      title: label,
      muted: true,
    );
  }
}

class _OutlinedRow extends StatelessWidget {
  const _OutlinedRow({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.muted = false,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: muted ? FontWeight.w500 : FontWeight.w700,
                          color: scheme.onSurface.withValues(alpha: muted ? 0.55 : 1),
                        ),
                      ),
                      if (subtitle != null)
                        Text(subtitle!, style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.55))),
                    ],
                  ),
                ),
                ?trailing,
                if (trailing == null) const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PublishBar extends StatelessWidget {
  const _PublishBar({required this.enabled, required this.uploading, required this.progress, required this.onPressed});

  final bool enabled;
  final bool uploading;
  final (int, int)? progress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final (done, total) = progress ?? (0, 0);
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08))),
      ),
      child: SizedBox(
        height: 52,
        child: FilledButton(
          onPressed: enabled && !uploading ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.onSurface,
            foregroundColor: scheme.surface,
            disabledBackgroundColor: scheme.onSurface.withValues(alpha: uploading ? 0.7 : 0.15),
            disabledForegroundColor: uploading ? scheme.surface : scheme.onSurface.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          child: uploading
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: scheme.surface,
                        backgroundColor: scheme.surface.withValues(alpha: 0.25),
                        value: total == 0 ? null : (done / total).clamp(0.05, 1.0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(total == 0 || done >= total ? 'Publishing…' : 'Uploading ${done + 1} of $total…'),
                  ],
                )
              : const Text('Publish post'),
        ),
      ),
    );
  }
}
