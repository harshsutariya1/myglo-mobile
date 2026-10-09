import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/location/address_geocoder.dart';
import '../../../../core/location/device_location.dart';
import '../../../../core/location/geo_point.dart';
import '../../../../core/maps/app_map.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../shared/authentication/models/profile_model.dart';
import '../../../shared/bookings/models/booking_failure.dart';
import '../../schedule/controllers/provider_schedule_controller.dart';

/// Where a provider's studio is: drag the map under a fixed pin, jump to
/// their current location or search an address, then confirm the address
/// text clients see. The address is pre-filled from the pin with the
/// device's free geocoder and can be edited before saving.
class BusinessLocationScreen extends ConsumerStatefulWidget {
  const BusinessLocationScreen({super.key});

  @override
  ConsumerState<BusinessLocationScreen> createState() => _BusinessLocationScreenState();
}

class _BusinessLocationScreenState extends ConsumerState<BusinessLocationScreen> {
  static const int _addressMaxLength = 200;
  static const int _addressMinLength = 5;
  static const Duration _lookupDelay = Duration(milliseconds: 450);

  final _address = TextEditingController();
  final _search = TextEditingController();
  final _addressFocus = FocusNode();
  final _sheetKey = GlobalKey();

  AppMapController? _map;
  late final MapCamera _initialCamera;
  late GeoPoint _point;
  GeoPoint? _savedPoint;
  String _savedAddress = '';

  /// Address the geocoder suggests for the pin; null while unknown.
  String? _suggested;
  bool _lookingUp = false;
  Timer? _lookupTimer;
  int _lookupSequence = 0;

  /// The provider typed in the address field, so the pin stops overwriting it.
  bool _addressEdited = false;
  bool _moving = false;
  bool _locating = false;
  bool _searching = false;
  bool _saving = false;
  bool _locationGranted = false;

  /// Set once the screen may close without asking (saved or discarded).
  bool _allowPop = false;
  String? _searchError;
  double _sheetHeight = 320;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider).value?.profile;
    _savedPoint = profile?.location;
    _savedAddress = profile?.addressText?.trim() ?? '';
    _point = _savedPoint ?? AppConfig.mapDefaultCenter;
    _initialCamera = MapCamera(
      target: _point,
      zoom: _savedPoint == null ? AppConfig.mapDefaultZoom : AppConfig.mapStreetZoom,
    );
    _address.text = _savedAddress;
    _addressEdited = _savedAddress.isNotEmpty;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _measureSheet();
      final access = await ref.read(deviceLocationProvider).access();
      if (mounted && access == LocationAccess.granted) setState(() => _locationGranted = true);
      if (_savedPoint != null) _scheduleLookup(_point, immediately: true);
    });
  }

  @override
  void dispose() {
    _lookupTimer?.cancel();
    _address.dispose();
    _search.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  void _measureSheet() {
    final box = _sheetKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if ((box.size.height - _sheetHeight).abs() > 1) setState(() => _sheetHeight = box.size.height);
  }

  bool get _hasChanges => _point != _savedPoint || _address.text.trim() != _savedAddress;

  /// Moves the pin to [point]. Without a map (no Maps key on this build)
  /// the pin is set directly so search and "current location" still work.
  Future<void> _moveTo(GeoPoint point) async {
    _addressEdited = false;
    final map = _map;
    if (map != null) {
      // The pin follows when the map settles (see _onCameraIdle).
      await map.animateTo(point, zoom: AppConfig.mapStreetZoom);
      return;
    }
    setState(() => _point = point);
    _scheduleLookup(point, immediately: true);
  }

  void _close() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  String? get _addressError {
    final text = _address.text.trim();
    if (text.isEmpty) return null;
    if (text.length < _addressMinLength) return 'Enter the full street address.';
    return null;
  }

  bool get _canSave =>
      !_saving && !_moving && _point.isInAustralia && _address.text.trim().length >= _addressMinLength;

  // ---------------------------------------------------------------------------
  // Pin and address
  // ---------------------------------------------------------------------------

  void _onCameraIdle(MapCamera camera) {
    final moved = camera.target != _point;
    setState(() {
      _moving = false;
      _point = camera.target;
    });
    if (moved) _scheduleLookup(camera.target);
  }

  void _scheduleLookup(GeoPoint point, {bool immediately = false}) {
    _lookupTimer?.cancel();
    final sequence = ++_lookupSequence;
    setState(() => _lookingUp = true);
    _lookupTimer = Timer(immediately ? Duration.zero : _lookupDelay, () => _lookup(point, sequence));
  }

  Future<void> _lookup(GeoPoint point, int sequence) async {
    String? address;
    try {
      address = await ref.read(reverseGeocoderProvider).describe(point);
    } on GeocodingUnavailableException {
      address = null;
    }
    if (!mounted || sequence != _lookupSequence) return;
    setState(() {
      _lookingUp = false;
      _suggested = address;
      if (!_addressEdited && address != null) _address.text = address;
    });
  }

  void _useSuggestion() {
    final suggestion = _suggested;
    if (suggestion == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _address.text = suggestion;
      _addressEdited = false;
    });
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    final location = ref.read(deviceLocationProvider);
    var access = await location.access();
    if (access == LocationAccess.denied) access = await location.requestAccess();
    if (!mounted) return;
    switch (access) {
      case LocationAccess.granted:
        setState(() {
          _locationGranted = true;
          _locating = true;
        });
        try {
          final point = await location.current();
          if (!mounted) return;
          if (!point.isInAustralia) {
            context.showAppSnackBar('Your location looks like it\'s outside Australia. Move the pin to your studio.',
                isError: true);
          }
          await _moveTo(point);
        } on LocationUnavailableException {
          if (mounted) context.showAppSnackBar("We couldn't find your location. Please try again.", isError: true);
        } finally {
          if (mounted) setState(() => _locating = false);
        }
      case LocationAccess.deniedForever:
        context.showAppSnackBar(
          'Allow location access in Settings, or move the pin by hand.',
          action: SnackBarAction(label: 'Settings', onPressed: location.openAppSettings),
        );
      case LocationAccess.serviceDisabled:
        context.showAppSnackBar(
          'Turn on location services, or move the pin by hand.',
          action: SnackBarAction(label: 'Turn on', onPressed: location.openLocationSettings),
        );
      case LocationAccess.denied:
        break;
    }
  }

  Future<void> _searchAddress(String text) async {
    final query = text.trim();
    FocusScope.of(context).unfocus();
    if (query.length < _addressMinLength) {
      setState(() => _searchError = 'Type a street address, suburb or postcode.');
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final withCountry = query.toLowerCase().contains('australia') ? query : '$query, Australia';
      final point = await ref.read(addressGeocoderProvider).locate(withCountry);
      if (!mounted) return;
      if (point == null || !point.isInAustralia) {
        setState(() => _searchError = point == null
            ? "We couldn't find that address. Try adding the suburb or postcode."
            : "That address doesn't look like it's in Australia.");
        return;
      }
      await _moveTo(point);
    } on GeocodingUnavailableException {
      if (mounted) setState(() => _searchError = "We can't look up addresses right now. Check your connection.");
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref
          .read(providerScheduleActionsProvider)
          .setBusinessLocation(addressText: _address.text.trim(), point: _point);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      context.showAppSnackBar('Studio location saved');
      _close();
    } on BookingFailure catch (failure) {
      if (mounted) context.showAppSnackBar(failure.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text("Your studio location won't be updated."),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep editing')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Discard')),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final padding = MediaQuery.paddingOf(context);
    final settings = ref.watch(ownBookingSettingsProvider).value;
    final mobileOnly = settings != null && !settings.offersStudio && settings.offersMobile;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureSheet());

    return PopScope(
      canPop: _allowPop || !_hasChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving) return;
        if (await _confirmDiscard() && mounted) _close();
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Positioned.fill(
              child: AppMap(
                initialCamera: _initialCamera,
                showMyLocation: _locationGranted,
                // The sheet covers the bottom; keep the centre and the
                // Google logo in the visible part.
                padding: EdgeInsets.only(top: padding.top + 64, bottom: _sheetHeight),
                onCreated: (controller) => _map = controller,
                onCameraMoveStarted: () {
                  if (!_moving) setState(() => _moving = true);
                  FocusScope.of(context).unfocus();
                },
                onCameraIdle: _onCameraIdle,
                onTap: (point) => _map?.animateTo(point),
              ),
            ),
            // The pin stays put while the map moves underneath it; its tip
            // marks the centre of the visible map.
            Positioned(
              top: padding.top + 64,
              left: 0,
              right: 0,
              bottom: _sheetHeight,
              child: IgnorePointer(child: Center(child: _CenterPin(lifted: _moving))),
            ),
            Positioned(
              top: padding.top + 8,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _FloatingButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SearchBox(
                          controller: _search,
                          busy: _searching,
                          onSubmitted: _searchAddress,
                        ),
                      ),
                    ],
                  ),
                  if (_searchError != null) ...[
                    const SizedBox(height: 8),
                    _Notice(message: _searchError!, onClose: () => setState(() => _searchError = null)),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Sheet(
                key: _sheetKey,
                bottomPadding: padding.bottom,
                mobileOnly: mobileOnly,
                addressController: _address,
                addressFocus: _addressFocus,
                addressError: _addressError,
                suggested: _suggested,
                lookingUp: _lookingUp || _moving,
                outsideAustralia: !_point.isInAustralia,
                locating: _locating,
                saving: _saving,
                canSave: _canSave,
                pinSet: _savedPoint != null || _point != AppConfig.mapDefaultCenter,
                onAddressChanged: (_) => setState(() => _addressEdited = true),
                onUseSuggestion: _useSuggestion,
                onUseCurrentLocation: _useCurrentLocation,
                onSave: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The map pin; rises while the map is being dragged.
class _CenterPin extends StatelessWidget {
  const _CenterPin({required this.lifted});

  final bool lifted;

  static const double _head = 44;
  static const double _stem = 14;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    // Shift up by the pin's height so its tip, not its middle, is on centre.
    return Transform.translate(
      offset: const Offset(0, -(_head + _stem) / 2),
      child: SizedBox(
        width: _head,
        height: _head + _stem + 6,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // Ground shadow: shrinks as the pin lifts.
            Positioned(
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: lifted ? 8 : 14,
                height: lifted ? 3 : 5,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: lifted ? 0.15 : 0.28),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              top: lifted ? -10 : 0,
              child: Column(
                children: [
                  Container(
                    width: _head,
                    height: _head,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.primaryPink, AppTheme.burntOrange],
                      ),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(color: scheme.primary.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 21),
                  ),
                  Container(
                    width: 3,
                    height: _stem,
                    decoration: BoxDecoration(color: scheme.onSurface, borderRadius: BorderRadius.circular(2)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingButton extends StatelessWidget {
  const _FloatingButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: context.colorScheme.surface,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          constraints: const BoxConstraints.tightFor(width: 52, height: 52),
          icon: Icon(icon, color: context.colorScheme.onSurface),
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.busy, required this.onSubmitted});

  final TextEditingController controller;
  final bool busy;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        child: TextField(
          controller: controller,
          enabled: !busy,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [LengthLimitingTextInputFormatter(200)],
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            hintText: 'Search an address',
            hintStyle: TextStyle(fontWeight: FontWeight.w500, color: scheme.onSurface.withValues(alpha: 0.4)),
            prefixIcon: Icon(Icons.search_rounded, color: scheme.primary),
            suffixIcon: busy
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.destructive),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface)),
          ),
          IconButton(
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, size: 18, color: scheme.onSurface.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    super.key,
    required this.bottomPadding,
    required this.mobileOnly,
    required this.addressController,
    required this.addressFocus,
    required this.addressError,
    required this.suggested,
    required this.lookingUp,
    required this.outsideAustralia,
    required this.locating,
    required this.saving,
    required this.canSave,
    required this.pinSet,
    required this.onAddressChanged,
    required this.onUseSuggestion,
    required this.onUseCurrentLocation,
    required this.onSave,
  });

  final double bottomPadding;
  final bool mobileOnly;
  final TextEditingController addressController;
  final FocusNode addressFocus;
  final String? addressError;
  final String? suggested;
  final bool lookingUp;
  final bool outsideAustralia;
  final bool locating;
  final bool saving;
  final bool canSave;
  final bool pinSet;
  final ValueChanged<String> onAddressChanged;
  final VoidCallback onUseSuggestion;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final suggestion = suggested;
    final showSuggestion = !lookingUp &&
        suggestion != null &&
        suggestion.toLowerCase() != addressController.text.trim().toLowerCase();

    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + bottomPadding),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            mobileOnly ? 'Set your base location' : 'Pin your studio',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            pinSet
                ? 'Move the map so the pin sits right on your entrance.'
                : 'Use your current location, search an address, or move the map to place the pin.',
            style: TextStyle(fontSize: 13.5, height: 1.35, color: muted),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: locating ? null : onUseCurrentLocation,
            icon: locating
                ? SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary))
                : Icon(Icons.my_location_rounded, size: 18, color: scheme.primary),
            label: Text(locating ? 'Finding you…' : 'Use my current location'),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.onSurface,
              minimumSize: const Size(0, 46),
              side: BorderSide(color: scheme.primary.withValues(alpha: 0.45)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: addressController,
            focusNode: addressFocus,
            onChanged: onAddressChanged,
            minLines: 1,
            maxLines: 2,
            maxLength: _BusinessLocationScreenState._addressMaxLength,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.fullStreetAddress],
            decoration: InputDecoration(
              labelText: mobileOnly ? 'Your address (private)' : 'Address clients see',
              hintText: 'e.g. Shop 3, 1 Cavill Ave, Surfers Paradise QLD 4217',
              counterText: '',
              errorText: addressError,
              prefixIcon: Icon(Icons.location_on_outlined, color: scheme.secondary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: lookingUp
                ? const Shimmer(child: SkeletonBox(height: 34, borderRadius: 999))
                : showSuggestion
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: ActionChip(
                          avatar: Icon(Icons.auto_fix_high_rounded, size: 16, color: scheme.secondary),
                          label: Text('Use “$suggestion”', maxLines: 1, overflow: TextOverflow.ellipsis),
                          onPressed: onUseSuggestion,
                          shape: const StadiumBorder(),
                          side: BorderSide(color: scheme.secondary.withValues(alpha: 0.3)),
                          backgroundColor: scheme.secondary.withValues(alpha: 0.06),
                          labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurface),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                outsideAustralia ? Icons.error_outline_rounded : Icons.visibility_outlined,
                size: 16,
                color: outsideAustralia ? AppTheme.destructive : muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  outsideAustralia
                      ? 'The pin must be in Australia.'
                      : mobileOnly
                          ? "Clients don't see this address; it's used to work out travel distance."
                          : 'Clients see this address and the pin when they book a studio visit.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: outsideAustralia ? FontWeight.w700 : FontWeight.w500,
                    color: outsideAustralia ? AppTheme.destructive : muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: canSave ? onSave : null,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.onSurface,
              foregroundColor: scheme.surface,
              minimumSize: const Size(0, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            child: saving
                ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.surface))
                : const Text('Save location'),
          ),
        ],
      ),
    );
  }
}
