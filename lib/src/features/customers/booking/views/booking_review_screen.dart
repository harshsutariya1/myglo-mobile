import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../shared/bookings/controllers/booking_controllers.dart';
import '../../../shared/bookings/models/available_slot.dart';
import '../../../shared/bookings/models/booking_enums.dart';
import '../../../shared/bookings/models/booking_settings.dart';
import '../../../shared/bookings/models/booking_terms.dart';
import '../../../shared/bookings/models/booking_time.dart';
import '../../../shared/bookings/models/cancellation_policy.dart';
import '../../../shared/bookings/views/widgets/booking_card.dart';
import '../../../shared/bookings/views/widgets/booking_summary.dart';
import '../../provider_profile/controllers/public_provider_profile_controller.dart';
import '../../provider_profile/views/widgets/provider_profile_header.dart';
import '../../provider_profile/views/widgets/section_states.dart';
import '../controllers/availability_controller.dart';
import '../controllers/booking_draft_controller.dart';
import '../controllers/service_selection_controller.dart';
import '../models/booking_draft.dart';
import '../models/service_selection.dart';
import 'booking_flow_navigation.dart';
import 'widgets/booking_flow_scaffold.dart';

/// Contact numbers accepted for a booking: 8–15 digits, optional leading +.
final RegExp _phonePattern = RegExp(r'^\+?\d{8,15}$');

String? validateBookingPhone(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'[\s().-]'), '');
  if (digits.isEmpty) return 'Add a number the provider can reach you on';
  if (!_phonePattern.hasMatch(digits)) return 'Enter a valid phone number';
  return null;
}

/// Step 4: everything about the booking on one page, priced line by line,
/// plus the client's contact number and notes.
///
/// The chosen time is checked again when the page opens, so the client
/// learns before paying if it was taken in the meantime.
class BookingReviewScreen extends ConsumerStatefulWidget {
  const BookingReviewScreen({super.key, required this.providerId});

  final String providerId;

  static const int maxNotesLength = 500;

  @override
  ConsumerState<BookingReviewScreen> createState() => _BookingReviewScreenState();
}

class _BookingReviewScreenState extends ConsumerState<BookingReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phone;
  late final TextEditingController _notes;

  String get _providerId => widget.providerId;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(bookingDraftProvider(_providerId));
    final profilePhone = ref.read(userProfileProvider).value?.profile.phoneNumber ?? '';
    _phone = TextEditingController(text: draft.phone ?? profilePhone);
    _notes = TextEditingController(text: draft.notes);
  }

  @override
  void dispose() {
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _continue() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.heavyImpact();
      return;
    }
    final controller = ref.read(bookingDraftProvider(_providerId).notifier);
    controller.setPhone(_phone.text.trim());
    controller.setNotes(_notes.text.trim());
    pushBookingStep(context, AppRoute.bookingPayment, _providerId);
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(serviceSelectionProvider(_providerId));
    final draft = ref.watch(bookingDraftProvider(_providerId));
    final settings = ref.watch(bookingSettingsProvider(_providerId)).value;
    final provider = ref.watch(publicProviderProfileProvider(_providerId)).value;
    final slot = draft.slot;
    final ready = selection.isNotEmpty && slot != null && draft.hasLocation && settings != null && provider != null;
    final terms = settings == null ? null : BookingTerms.of(settings, draft.paymentMethod);

    return BookingFlowScaffold(
      step: BookingStep.review,
      title: 'Review',
      subtitle: provider == null ? null : providerDisplayName(provider),
      footer: BookingFooter(
        actionLabel: 'Continue to payment',
        onAction: ready ? _continue : null,
        summary: BookingFooterSummary(caption: 'Total', value: Formatters.audCents(selection.totalCents)),
      ),
      body: !ready
          ? (selection.isEmpty || slot == null || !draft.hasLocation)
              ? _IncompleteView(draft: draft, selection: selection)
              : const _ReviewSkeleton()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  _SlotStillFree(providerId: _providerId, slot: slot, selection: selection),
                  Row(
                    children: [
                      PersonAvatar(name: providerDisplayName(provider), url: provider.profilePic, size: 52),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              providerDisplayName(provider),
                              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: context.colorScheme.onSurface),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              terms!.requiresApproval ? 'Confirms requests personally' : 'Instant confirmation',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: terms.requiresApproval ? AppTheme.warning : AppTheme.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const BookingSectionLabel('Appointment'),
                  _AppointmentCard(
                    slot: slot,
                    draft: draft,
                    selection: selection,
                    settings: settings,
                    studioAddress: provider.addressText?.trim() ?? '',
                    onChangeTime: () => popBookingFlowTo(context, AppRoute.selectDateTime),
                    onChangeLocation: () => popBookingFlowTo(context, AppRoute.bookingLocation),
                  ),
                  const SizedBox(height: 22),
                  BookingSectionLabel(
                    'Price',
                    trailing: TextButton(
                      onPressed: () => popBookingFlowTo(context, AppRoute.selectServices),
                      style: TextButton.styleFrom(
                        foregroundColor: context.colorScheme.secondary,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Edit services'),
                    ),
                  ),
                  BookingSectionCard(
                    child: PriceBreakdown(
                      lines: [
                        for (final service in selection.services)
                          (
                            label: service.name,
                            detail: Formatters.duration(service.durationMinutes),
                            cents: (service.price * 100).round(),
                          ),
                      ],
                      totalCents: selection.totalCents,
                      footnote: 'Prices are set by ${providerDisplayName(provider)} in AUD. You pay at your appointment.',
                    ),
                  ),
                  const SizedBox(height: 22),
                  const BookingSectionLabel('Your details'),
                  BookingSectionCard(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s()-]'))],
                          validator: validateBookingPhone,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDecoration(
                            context,
                            label: 'Mobile number',
                            hint: '04XX XXX XXX',
                            icon: Icons.phone_iphone_rounded,
                            helper: 'Shared with ${providerDisplayName(provider)} for this booking only',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _notes,
                          maxLines: 4,
                          minLines: 2,
                          maxLength: BookingReviewScreen.maxNotesLength,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _inputDecoration(
                            context,
                            label: 'Notes for ${providerDisplayName(provider)} (optional)',
                            hint: 'Allergies, preferences, anything they should know',
                            icon: Icons.edit_note_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (terms.requiresApproval) ...[
                    BookingNotice(
                      icon: Icons.hourglass_top_rounded,
                      color: AppTheme.warning,
                      title: 'This is a booking request',
                      body:
                          '${draft.paymentMethod.isCash ? "You're paying in cash, so ${providerDisplayName(provider)} confirms "
                              'this booking personally' : '${providerDisplayName(provider)} confirms each booking personally'}. '
                          "Your time is held while they review it, and we'll let you know as soon as they respond.",
                    ),
                    const SizedBox(height: 12),
                  ],
                  BookingNotice(
                    icon: Icons.event_available_outlined,
                    title: 'Cancellation policy',
                    body: CancellationPolicy.forBooking(
                      freeUntilLocal: slot.local.subtract(Duration(hours: terms.cancellationWindowHours)),
                      windowHours: terms.cancellationWindowHours,
                      feePercent: terms.cancellationFeePercent,
                      totalCents: selection.totalCents,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

InputDecoration _inputDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  required IconData icon,
  String? helper,
}) {
  final scheme = context.colorScheme;
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 2,
    prefixIcon: Icon(icon, size: 20),
    filled: true,
    fillColor: scheme.onSurface.withValues(alpha: 0.025),
    border: border(scheme.onSurface.withValues(alpha: 0.1)),
    enabledBorder: border(scheme.onSurface.withValues(alpha: 0.1)),
    focusedBorder: border(scheme.primary, 1.6),
    errorBorder: border(scheme.error),
    focusedErrorBorder: border(scheme.error, 1.6),
  );
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.slot,
    required this.draft,
    required this.selection,
    required this.settings,
    required this.studioAddress,
    required this.onChangeTime,
    required this.onChangeLocation,
  });

  final AvailableSlot slot;
  final BookingDraft draft;
  final ServiceSelection selection;
  final ProviderBookingSettings settings;
  final String studioAddress;
  final VoidCallback onChangeTime;
  final VoidCallback onChangeLocation;

  @override
  Widget build(BuildContext context) {
    final atHome = draft.locationType == BookingLocationType.client;
    final address = atHome ? draft.address?.formatted ?? '' : studioAddress;
    final distance = draft.distanceKm;
    final divider = Divider(height: 26, thickness: 1, color: context.colorScheme.onSurface.withValues(alpha: 0.07));

    return BookingSectionCard(
      child: Column(
        children: [
          BookingDetailRow(
            icon: Icons.calendar_today_rounded,
            title: Formatters.dateLong(slot.local, currentYear: BookingTime.todayIn(settings.timeZone).year),
            subtitle:
                '${Formatters.timeRange(slot.local, slot.localEnd(selection.totalMinutes))} · ${BookingTime.label(settings.timeZone, offset: slot.utcOffset)}',
            onChange: onChangeTime,
          ),
          divider,
          BookingDetailRow(
            icon: Icons.timelapse_rounded,
            title: Formatters.duration(selection.totalMinutes),
            subtitle: selection.countLabel,
          ),
          divider,
          BookingDetailRow(
            icon: atHome ? Icons.home_outlined : Icons.storefront_outlined,
            title: atHome ? 'At your place' : 'At the studio',
            subtitle: [
              address,
              if (atHome && distance != null) '${Formatters.distanceKm(distance)} from the provider',
              if (atHome && draft.accessNotes.isNotEmpty) 'Note: ${draft.accessNotes}',
            ].join('\n'),
            onChange: onChangeLocation,
          ),
        ],
      ),
    );
  }
}

/// Re-checks the chosen time when the review opens and warns if it went.
class _SlotStillFree extends ConsumerWidget {
  const _SlotStillFree({required this.providerId, required this.slot, required this.selection});

  final String providerId;
  final AvailableSlot slot;
  final ServiceSelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = SlotRequest(
      providerId: providerId,
      serviceIds: [for (final service in selection.services) service.id],
      from: slot.day,
      to: slot.day,
    );
    final day = ref.watch(availableSlotsProvider(request)).value;
    if (day == null || day.contains(slot)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: AppTheme.destructive.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_busy_rounded, color: AppTheme.destructive, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This time is no longer available.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colorScheme.onSurface),
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(bookingDraftProvider(providerId).notifier).clearSlot();
                  popBookingFlowTo(context, AppRoute.selectDateTime);
                },
                style: TextButton.styleFrom(foregroundColor: AppTheme.destructive),
                child: const Text('Pick another'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncompleteView extends StatelessWidget {
  const _IncompleteView({required this.draft, required this.selection});

  final BookingDraft draft;
  final ServiceSelection selection;

  @override
  Widget build(BuildContext context) {
    final (target, label) = selection.isEmpty
        ? (AppRoute.selectServices, 'Choose services')
        : draft.slot == null
            ? (AppRoute.selectDateTime, 'Choose a time')
            : (AppRoute.bookingLocation, 'Choose a location');
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SectionEmptyView(
              icon: Icons.checklist_rounded,
              title: 'A few details are missing',
              message: 'Finish the earlier steps to review your booking.',
            ),
            FilledButton(onPressed: () => popBookingFlowTo(context, target), child: Text(label)),
          ],
        ),
      ),
    );
  }
}

class _ReviewSkeleton extends StatelessWidget {
  const _ReviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: const [
          Row(
            children: [
              SkeletonBox.circle(size: 52),
              SizedBox(width: 14),
              Expanded(child: SkeletonText(style: TextStyle(fontSize: 19), widthFactor: 0.6)),
            ],
          ),
          SizedBox(height: 22),
          SkeletonBox(height: 220, borderRadius: 20),
          SizedBox(height: 22),
          SkeletonBox(height: 200, borderRadius: 20),
        ],
      ),
    );
  }
}
