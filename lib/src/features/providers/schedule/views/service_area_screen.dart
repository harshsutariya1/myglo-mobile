import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/address_geocoder.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../../customers/booking/views/widgets/location_preview.dart';
import '../../../customers/provider_profile/views/widgets/section_states.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../shared/bookings/controllers/booking_controllers.dart';
import '../../../shared/bookings/models/booking_failure.dart';
import '../../../shared/bookings/models/booking_settings.dart';
import '../controllers/provider_schedule_controller.dart';

/// Where the provider works: at their studio, at clients' homes (and how far
/// they travel), and the business location both are measured from.
class ServiceAreaScreen extends ConsumerStatefulWidget {
  const ServiceAreaScreen({super.key});

  @override
  ConsumerState<ServiceAreaScreen> createState() => _ServiceAreaScreenState();
}

class _ServiceAreaScreenState extends ConsumerState<ServiceAreaScreen> {
  /// Travel limits offered, in km; null means no limit.
  static const List<double?> radiusOptions = [5, 10, 15, 25, 40, 60, null];

  final _address = TextEditingController();
  bool _addressLoaded = false;
  bool _locating = false;
  String? _locationError;

  /// The setting being saved, so its control can show progress.
  String? _savingKey;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _update(String key, Map<String, Object?> changes) async {
    setState(() => _savingKey = key);
    try {
      await ref.read(providerScheduleActionsProvider).updateSettings(changes);
      HapticFeedback.selectionClick();
    } on BookingFailure catch (failure) {
      if (mounted) context.showAppSnackBar(failure.message, isError: true);
    } finally {
      if (mounted) setState(() => _savingKey = null);
    }
  }

  Future<void> _locate() async {
    final text = _address.text.trim();
    FocusScope.of(context).unfocus();
    if (text.length < 8) {
      setState(() => _locationError = 'Enter your full business address, including suburb and postcode.');
      return;
    }
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final query = text.toLowerCase().contains('australia') ? text : '$text, Australia';
      final point = await ref.read(addressGeocoderProvider).locate(query);
      if (!mounted) return;
      if (point == null || !point.isInAustralia) {
        setState(() {
          _locating = false;
          _locationError = point == null
              ? "We couldn't find that address. Check the street, suburb and postcode."
              : "That address doesn't look like it's in Australia.";
        });
        return;
      }
      await ref.read(providerScheduleActionsProvider).setBusinessLocation(addressText: text, point: point);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _locating = false);
      context.showAppSnackBar('Business location saved');
    } on GeocodingUnavailableException {
      if (mounted) {
        setState(() {
          _locating = false;
          _locationError = "We can't look up addresses right now. Check your connection and try again.";
        });
      }
    } on BookingFailure catch (failure) {
      if (mounted) {
        setState(() {
          _locating = false;
          _locationError = failure.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final async = ref.watch(ownBookingSettingsProvider);
    final settings = async.value;
    final profile = ref.watch(userProfileProvider.select((p) => p.value?.profile));
    final savedAddress = profile?.addressText?.trim() ?? '';
    final located = profile?.coordinates != null && savedAddress.isNotEmpty;
    if (!_addressLoaded && profile != null) {
      _address.text = savedAddress;
      _addressLoaded = true;
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('Where you work'),
      ),
      body: switch (settings) {
        null when async.hasError => Center(
            child: SingleChildScrollView(
              child: SectionErrorView(
                title: "Settings didn't load",
                message: describeLoadError(async.error!, subject: 'your booking settings'),
                onRetry: () {
                  final providerId = ref.read(currentProviderIdProvider);
                  if (providerId != null) ref.invalidate(bookingSettingsProvider(providerId));
                },
              ),
            ),
          ),
        null => const Shimmer(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  SkeletonBox(height: 150, borderRadius: 20),
                  SizedBox(height: 16),
                  SkeletonBox(height: 260, borderRadius: 20),
                ],
              ),
            ),
          ),
        final settings => ListView(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 32 + MediaQuery.paddingOf(context).bottom),
            children: [
              _SectionTitle('Appointments'),
              _ModeTile(
                icon: Icons.storefront_outlined,
                title: 'At your studio',
                subtitle: 'Clients come to your business address',
                value: settings.offersStudio,
                saving: _savingKey == 'studio',
                onChanged: _savingKey != null
                    ? null
                    : (value) {
                        if (!value && !settings.offersMobile) {
                          context.showAppSnackBar('Offer at least one: your studio or mobile visits.', isError: true);
                          return;
                        }
                        _update('studio', {'offers_studio': value});
                      },
              ),
              const SizedBox(height: 10),
              _ModeTile(
                icon: Icons.directions_car_outlined,
                title: 'Mobile visits',
                subtitle: "You travel to clients' homes",
                value: settings.offersMobile,
                saving: _savingKey == 'mobile',
                onChanged: _savingKey != null
                    ? null
                    : (value) {
                        if (!value && !settings.offersStudio) {
                          context.showAppSnackBar('Offer at least one: your studio or mobile visits.', isError: true);
                          return;
                        }
                        _update('mobile', {'offers_mobile': value});
                      },
              ),
              const SizedBox(height: 26),
              _SectionTitle('Business location'),
              _LocationCard(
                controller: _address,
                savedAddress: savedAddress,
                located: located,
                locating: _locating,
                error: _locationError,
                onLocate: _locate,
                onChanged: () {
                  if (_locationError != null) setState(() => _locationError = null);
                },
              ),
              if (settings.offersMobile) ...[
                const SizedBox(height: 26),
                _SectionTitle('How far you travel'),
                _RadiusPicker(
                  settings: settings,
                  options: radiusOptions,
                  located: located,
                  saving: _savingKey == 'radius',
                  onSelected: _savingKey != null ? null : (km) => _update('radius', {'travel_radius_km': km}),
                ),
              ],
            ],
          ),
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
      child: Semantics(
        header: true,
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: context.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.saving,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool saving;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: value ? scheme.secondary.withValues(alpha: 0.45) : scheme.onSurface.withValues(alpha: 0.08),
          width: value ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: value ? 0.16 : 0.07),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 21, color: scheme.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.6))),
              ],
            ),
          ),
          if (saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.controller,
    required this.savedAddress,
    required this.located,
    required this.locating,
    required this.error,
    required this.onLocate,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String savedAddress;
  final bool located;
  final bool locating;
  final String? error;
  final VoidCallback onLocate;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LocationPreview(label: savedAddress.isEmpty ? 'Your business' : savedAddress, height: 130),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                located ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                size: 18,
                color: located ? AppTheme.success : AppTheme.warning,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  located ? 'Location set' : 'Not set yet. Clients need it to book you.',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: scheme.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            enabled: !locating,
            onChanged: (_) => onChanged(),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onLocate(),
            autofillHints: const [AutofillHints.fullStreetAddress],
            maxLength: 200,
            decoration: InputDecoration(
              labelText: 'Business address',
              hintText: 'e.g. 1 Cavill Ave, Surfers Paradise QLD 4217',
              counterText: '',
              errorText: error,
              errorMaxLines: 3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Clients see this address for studio appointments. For mobile visits it\'s only used to work out '
            'travel distance, never shown.',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.58)),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: locating ? null : onLocate,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.onSurface,
              foregroundColor: scheme.surface,
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            icon: locating
                ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.surface))
                : const Icon(Icons.my_location_rounded, size: 19),
            label: Text(located ? 'Update location' : 'Save location'),
          ),
        ],
      ),
    );
  }
}

class _RadiusPicker extends StatelessWidget {
  const _RadiusPicker({
    required this.settings,
    required this.options,
    required this.located,
    required this.saving,
    required this.onSelected,
  });

  final ProviderBookingSettings settings;
  final List<double?> options;
  final bool located;
  final bool saving;
  final ValueChanged<double?>? onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final current = settings.travelRadiusKm;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  current == null ? 'No distance limit' : 'Up to ${Formatters.distanceKm(current)} away',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: scheme.onSurface),
                ),
              ),
              if (saving) const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            settings.offersStudio
                ? 'Clients further away can still book you at your studio.'
                : "Clients further away won't be able to book you.",
            style: TextStyle(fontSize: 13, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final km in options)
                ChoiceChip(
                  label: Text(km == null ? 'No limit' : '${km.round()} km'),
                  selected: km == current || (km != null && current != null && (km - current).abs() < 0.05),
                  onSelected: onSelected == null || (km != null && !located) ? null : (_) => onSelected!(km),
                  showCheckmark: false,
                  labelStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  shape: const StadiumBorder(),
                ),
            ],
          ),
          if (!located) ...[
            const SizedBox(height: 10),
            Text(
              'Save your business location first to set a distance limit.',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.warning),
            ),
          ],
        ],
      ),
    );
  }
}
