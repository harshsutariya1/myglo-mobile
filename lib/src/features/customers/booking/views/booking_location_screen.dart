import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/address_geocoder.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../shared/authentication/models/profile_model.dart';
import '../../../shared/bookings/controllers/booking_controllers.dart';
import '../../../shared/bookings/models/availability_repository.dart';
import '../../../shared/bookings/models/booking_enums.dart';
import '../../../shared/bookings/models/booking_failure.dart';
import '../../../shared/bookings/models/booking_repository.dart';
import '../../../shared/bookings/models/booking_settings.dart';
import '../../../shared/bookings/models/client_address.dart';
import '../../provider_profile/controllers/public_provider_profile_controller.dart';
import '../../provider_profile/views/widgets/provider_profile_header.dart';
import '../../provider_profile/views/widgets/section_states.dart';
import '../controllers/booking_draft_controller.dart';
import 'booking_flow_navigation.dart';
import 'widgets/address_form.dart';
import 'widgets/booking_flow_scaffold.dart';
import 'widgets/location_option_card.dart';
import 'widgets/location_preview.dart';

/// The client's recent home-visit addresses, for one-tap reuse.
final recentAddressesProvider = FutureProvider.autoDispose<List<ClientAddress>>((ref) async {
  final clientId = ref.watch(userProfileProvider.select((p) => p.value?.isCustomer == true ? p.value?.rawUser.id : null));
  if (clientId == null) return const [];
  return ref.watch(bookingRepositoryProvider).recentAddresses(clientId);
});

/// Step 3: at the provider's studio, or at the client's place.
///
/// Home visits need an address the provider can reach: it's located and
/// checked against the provider's travel radius before the client can move
/// on (and checked again by the server when booking).
class BookingLocationScreen extends ConsumerStatefulWidget {
  const BookingLocationScreen({super.key, required this.providerId});

  final String providerId;

  @override
  ConsumerState<BookingLocationScreen> createState() => _BookingLocationScreenState();
}

class _BookingLocationScreenState extends ConsumerState<BookingLocationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AddressFormControllers _address;
  bool _checking = false;
  String? _addressError;

  String get _providerId => widget.providerId;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(bookingDraftProvider(_providerId));
    _address = AddressFormControllers(initial: draft.address, accessNotes: draft.accessNotes);
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  /// Keeps the draft in step with the form so going back and forth never
  /// loses what was typed.
  void _saveAddress() {
    ref.read(bookingDraftProvider(_providerId).notifier).setAddress(
          _address.address,
          accessNotes: _address.accessNotes.text.trim(),
        );
    if (_addressError != null) setState(() => _addressError = null);
  }

  void _useRecent(ClientAddress address) {
    HapticFeedback.selectionClick();
    _address.fill(address);
    _saveAddress();
    _formKey.currentState?.validate();
  }

  BookingLocationType? _effectiveType(BookingLocationType? chosen, ProviderBookingSettings settings, bool studioUsable) {
    if (chosen == BookingLocationType.studio && studioUsable) return chosen;
    if (chosen == BookingLocationType.client && settings.offersMobile) return chosen;
    if (studioUsable) return BookingLocationType.studio;
    if (settings.offersMobile) return BookingLocationType.client;
    return null;
  }

  Future<void> _continue(BookingLocationType type, String providerName) async {
    final draftController = ref.read(bookingDraftProvider(_providerId).notifier);
    draftController.selectLocation(type);
    if (type == BookingLocationType.studio) {
      pushBookingStep(context, AppRoute.bookingReview, _providerId);
      return;
    }

    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final address = _address.address;
    _saveAddress();
    final draft = ref.read(bookingDraftProvider(_providerId));
    if (draft.verifiedPoint != null && draft.address == address) {
      pushBookingStep(context, AppRoute.bookingReview, _providerId);
      return;
    }

    setState(() {
      _checking = true;
      _addressError = null;
    });
    String? error;
    try {
      final point = await ref.read(addressGeocoderProvider).locate(address.geocodingQuery);
      if (point == null) {
        error = "We couldn't find that address. Check the street, suburb and postcode.";
      } else {
        final check = await ref.read(availabilityRepositoryProvider).checkServiceArea(providerId: _providerId, point: point);
        if (!check.withinArea) {
          final distance = check.distanceKm == null ? 'too far' : '${Formatters.distanceKm(check.distanceKm!)} away';
          final radius = check.radiusKm == null ? '' : ' $providerName travels up to ${Formatters.distanceKm(check.radiusKm!)}.';
          error = 'That address is $distance, outside the travel area.$radius Choose their studio or another address.';
        } else {
          draftController.markAddressVerified(address, point, distanceKm: check.distanceKm);
        }
      }
    } on GeocodingUnavailableException {
      error = "We couldn't check that address right now. Check your connection and try again.";
    } catch (e) {
      error = BookingFailure.from(e).message;
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _addressError = error;
    });
    if (error == null) {
      HapticFeedback.lightImpact();
      pushBookingStep(context, AppRoute.bookingReview, _providerId);
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(bookingSettingsProvider(_providerId));
    final providerAsync = ref.watch(publicProviderProfileProvider(_providerId));
    final draft = ref.watch(bookingDraftProvider(_providerId));
    final provider = providerAsync.value;
    final providerName = provider == null ? 'The provider' : providerDisplayName(provider);

    final settings = settingsAsync.value;
    final studioAddress = provider?.addressText?.trim() ?? '';
    final studioUsable = settings != null && settings.offersStudio && studioAddress.isNotEmpty;
    final type = settings == null ? null : _effectiveType(draft.locationType, settings, studioUsable);

    return BookingFlowScaffold(
      step: BookingStep.location,
      title: 'Location',
      subtitle: provider == null ? null : providerName,
      footer: BookingFooter(
        actionLabel: _checking ? 'Checking address' : 'Continue',
        busy: _checking,
        onAction: type == null ? null : () => _continue(type, providerName),
        summary: type == null
            ? null
            : BookingFooterSummary(
                caption: 'Appointment',
                value: type == BookingLocationType.studio ? 'At the studio' : 'At your place',
              ),
      ),
      body: switch ((settingsAsync, providerAsync)) {
        (AsyncError(:final error), _) || (_, AsyncError(:final error)) => Center(
            child: SingleChildScrollView(
              child: SectionErrorView(
                title: "Location options didn't load",
                message: describeLoadError(error, subject: "this provider's details"),
                onRetry: () {
                  ref.invalidate(bookingSettingsProvider(_providerId));
                  ref.invalidate(publicProviderProfileProvider(_providerId));
                },
              ),
            ),
          ),
        _ when settings == null || provider == null => const _LocationSkeleton(),
        _ => _buildOptions(context, settings, provider, providerName, studioAddress, studioUsable, type),
      },
    );
  }

  Widget _buildOptions(
    BuildContext context,
    ProviderBookingSettings settings,
    ProfileModel provider,
    String providerName,
    String studioAddress,
    bool studioUsable,
    BookingLocationType? type,
  ) {
    final scheme = context.colorScheme;
    final radius = settings.travelRadiusKm;
    final recent = ref.watch(recentAddressesProvider).value ?? const <ClientAddress>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text(
          'Where would you like your appointment?',
          style: TextStyle(fontSize: 22, height: 1.25, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: scheme.onSurface),
        ),
        const SizedBox(height: 18),
        LocationOptionCard(
          icon: Icons.storefront_outlined,
          title: "At $providerName's studio",
          subtitle: studioAddress,
          selected: type == BookingLocationType.studio,
          onSelected: () => ref.read(bookingDraftProvider(_providerId).notifier).selectLocation(BookingLocationType.studio),
          disabledReason: studioUsable ? null : "This provider doesn't see clients at a studio",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LocationPreview(label: studioAddress),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.place_outlined, size: 18, color: scheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      studioAddress,
                      style: TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w600, color: scheme.onSurface),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LocationOptionCard(
          icon: Icons.home_outlined,
          title: 'At your place',
          subtitle: radius == null
              ? '$providerName travels to you'
              : '$providerName travels up to ${Formatters.distanceKm(radius)}',
          selected: type == BookingLocationType.client,
          onSelected: () => ref.read(bookingDraftProvider(_providerId).notifier).selectLocation(BookingLocationType.client),
          disabledReason: settings.offersMobile ? null : "This provider doesn't offer home visits",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (recent.isNotEmpty) ...[
                Text(
                  'Recent addresses',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final address in recent)
                      ActionChip(
                        avatar: Icon(Icons.history_rounded, size: 16, color: scheme.secondary),
                        label: Text(address.formatted, overflow: TextOverflow.ellipsis),
                        onPressed: _checking ? null : () => _useRecent(address),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.12)),
                        backgroundColor: scheme.surface,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              AddressForm(
                formKey: _formKey,
                controllers: _address,
                onChanged: _saveAddress,
                providerName: providerName,
                enabled: !_checking,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: _addressError == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: _AddressProblem(message: _addressError!),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                "We check the address is inside $providerName's travel area before you book. "
                'Only $providerName sees your address, and only for this booking.',
                style: TextStyle(fontSize: 12.5, height: 1.4, color: scheme.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddressProblem extends StatelessWidget {
  const _AddressProblem({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.destructive.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.wrong_location_outlined, size: 20, color: AppTheme.destructive),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 13.5, height: 1.45, color: context.colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationSkeleton extends StatelessWidget {
  const _LocationSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: const [
          SkeletonText(style: TextStyle(fontSize: 22, height: 1.25), widthFactor: 0.8),
          SizedBox(height: 18),
          SkeletonBox(height: 280, borderRadius: 22),
          SizedBox(height: 14),
          SkeletonBox(height: 78, borderRadius: 22),
        ],
      ),
    );
  }
}
