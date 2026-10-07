import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../../providers/provider_profiles/controllers/provider_services_controller.dart';
import '../../../providers/provider_profiles/models/service_model.dart';
import '../../../shared/services/views/widgets/service_details_sheet.dart';
import '../../provider_profile/controllers/public_provider_profile_controller.dart';
import '../../provider_profile/views/widgets/provider_profile_header.dart';
import '../../provider_profile/views/widgets/provider_services_tab.dart';
import '../../provider_profile/views/widgets/section_states.dart';
import '../controllers/booking_draft_controller.dart';
import '../controllers/service_selection_controller.dart';
import 'booking_flow_navigation.dart';
import 'widgets/booking_flow_scaffold.dart';
import 'widgets/category_chip_bar.dart';
import 'widgets/compact_service_list.dart';
import 'widgets/selectable_service_tile.dart';
import 'widgets/selected_services_sheet.dart';
import 'widgets/selection_summary_bar.dart';

/// Label of the first category pill, which lists every service compactly.
const String allServicesLabel = 'All';

/// First step of booking with a provider: pick one or more services.
///
/// Categories run along the top as pills, starting with "All" (every service
/// as a compact row); the services of the active category are listed below,
/// and the client can swipe or tap between categories. Selections persist
/// across categories, and once anything is selected a footer shows the
/// running total (tap to review) and Continue.
///
/// With [initialServiceId] (e.g. the "+" on a service), that service starts
/// selected and the screen opens on its category.
class SelectServicesScreen extends ConsumerStatefulWidget {
  const SelectServicesScreen({super.key, required this.providerId, this.initialServiceId});

  final String providerId;
  final String? initialServiceId;

  @override
  ConsumerState<SelectServicesScreen> createState() => _SelectServicesScreenState();
}

class _SelectServicesScreenState extends ConsumerState<SelectServicesScreen> {
  String get providerId => widget.providerId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialServiceId;
    if (initial != null && initial.isNotEmpty) {
      // Providers can't be modified while the tree is building. An id that
      // doesn't belong to this provider is dropped when the selection is
      // resolved against the loaded services.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(selectedServiceIdsProvider(providerId).notifier).select(initial);
      });
    }
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      // Opened directly (deep link) with nothing underneath.
      context.goNamed(AppRoute.publicProviderProfile.name, pathParameters: {'id': providerId});
    }
  }

  void _continue(BuildContext context) => pushBookingStep(context, AppRoute.selectDateTime, providerId);

  @override
  Widget build(BuildContext context) {
    // The draft (time, place, contact details) lives as long as the flow,
    // which starts here: stepping back to this screen keeps it.
    ref.listen(bookingDraftProvider(providerId), (_, _) {});
    final servicesAsync = ref.watch(providerServicesProvider(providerId));
    final selection = ref.watch(serviceSelectionProvider(providerId));
    final provider = ref.watch(publicProviderProfileProvider(providerId)).value;
    final scheme = context.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 0,
        leading: BackButton(onPressed: () => _goBack(context)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select services',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: scheme.onSurface),
            ),
            if (provider != null)
              Text(
                providerDisplayName(provider),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
          ],
        ),
        bottom: const BookingProgressBar(step: BookingStep.services),
      ),
      body: switch (servicesAsync) {
        AsyncValue(:final value?) when value.isNotEmpty => _ServiceCatalogue(
          providerId: providerId,
          services: value,
          initialServiceId: widget.initialServiceId,
        ),
        AsyncValue(value: _?) => const Center(
          child: SingleChildScrollView(
            child: SectionEmptyView(
              icon: Icons.content_cut_rounded,
              title: 'No services to book yet',
              message: "This provider hasn't published any services. Check back soon.",
            ),
          ),
        ),
        AsyncError(:final error) => Center(
          child: SingleChildScrollView(
            child: SectionErrorView(
              title: "Services didn't load",
              message: describeLoadError(error, subject: 'these services'),
              onRetry: () => ref.invalidate(providerServicesProvider(providerId)),
            ),
          ),
        ),
        _ => const _CatalogueSkeleton(),
      },
      bottomNavigationBar: SelectionSummaryBar(
        selection: selection,
        onReview: () => showSelectedServicesSheet(
          context,
          providerId: providerId,
          onContinue: () {
            if (context.mounted) _continue(context);
          },
        ),
        onContinue: () => _continue(context),
      ),
    );
  }
}

/// Category pills over a swipeable page per category; page 0 is "All".
class _ServiceCatalogue extends ConsumerStatefulWidget {
  const _ServiceCatalogue({required this.providerId, required this.services, this.initialServiceId});

  final String providerId;
  final List<ServiceModel> services;
  final String? initialServiceId;

  @override
  ConsumerState<_ServiceCatalogue> createState() => _ServiceCatalogueState();
}

class _ServiceCatalogueState extends ConsumerState<_ServiceCatalogue> {
  late final PageController _pageController;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = _initialPage();
    _pageController = PageController(initialPage: _page);
  }

  /// The page of the initial service's category, or "All" without one.
  int _initialPage() {
    final id = widget.initialServiceId;
    if (id == null) return 0;
    final groups = groupServicesByCategory(widget.services).values.toList();
    final index = groups.indexWhere((services) => services.any((s) => s.id == id));
    return index < 0 ? 0 : index + 1;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectCategory(int index) {
    if (index == _page) return;
    HapticFeedback.selectionClick();
    setState(() => _page = index);
    // Jump straight to distant categories instead of flicking through every
    // page in between.
    if ((index - (_pageController.page ?? _page)).abs() > 1) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(index, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    }
  }

  void _toggle(ServiceModel service) {
    HapticFeedback.selectionClick();
    ref.read(selectedServiceIdsProvider(widget.providerId).notifier).toggle(service.id);
  }

  void _showDetails(ServiceModel service) {
    final selected = ref.read(selectedServiceIdsProvider(widget.providerId)).contains(service.id);
    showServiceDetailsSheet(
      context,
      service: service,
      bookLabel: selected ? 'Remove from selection' : 'Add to selection',
      onBook: () => ref.read(selectedServiceIdsProvider(widget.providerId).notifier).toggle(service.id),
    );
  }

  Future<void> _refresh() async {
    try {
      ref.invalidate(providerServicesProvider(widget.providerId));
      await ref.read(providerServicesProvider(widget.providerId).future);
    } catch (error) {
      // Already reported by the repository. The services already on screen
      // stay put, so just say the refresh didn't go through.
      if (!mounted) return;
      context.showAppSnackBar(
        describeLoadError(error, subject: 'the latest services'),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = groupServicesByCategory(widget.services).entries.toList();
    final selectedIds = ref.watch(selectedServiceIdsProvider(widget.providerId)).toSet();
    bool isSelected(ServiceModel service) => selectedIds.contains(service.id);
    // A refresh can leave fewer categories than the one being shown.
    final page = _page.clamp(0, grouped.length);

    return Column(
      children: [
        CategoryChipBar(
          categories: [
            (label: allServicesLabel, selectedCount: widget.services.where(isSelected).length),
            for (final entry in grouped)
              (
                label: entry.key,
                selectedCount: entry.value.where(isSelected).length,
              ),
          ],
          selectedIndex: page,
          onSelected: _selectCategory,
        ),
        Divider(height: 1, thickness: 1, color: context.colorScheme.onSurface.withValues(alpha: 0.06)),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: grouped.length + 1,
            onPageChanged: (index) {
              if (index != _page) setState(() => _page = index);
            },
            itemBuilder: (context, index) => RefreshIndicator(
              color: context.colorScheme.primary,
              onRefresh: _refresh,
              child: index == 0
                  ? ListView(
                      key: const PageStorageKey('services-all'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 14, bottom: 24),
                      children: [
                        const CompactListHint(),
                        for (final entry in grouped)
                          CompactServiceGroup(
                            label: entry.key,
                            services: entry.value,
                            isSelected: isSelected,
                            onToggle: _toggle,
                            onShowDetails: _showDetails,
                          ),
                      ],
                    )
                  : _CategoryPage(
                      category: grouped[index - 1].key,
                      services: grouped[index - 1].value,
                      isSelected: isSelected,
                      onToggle: _toggle,
                      onShowDetails: _showDetails,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryPage extends StatelessWidget {
  const _CategoryPage({
    required this.category,
    required this.services,
    required this.isSelected,
    required this.onToggle,
    required this.onShowDetails,
  });

  final String category;
  final List<ServiceModel> services;
  final bool Function(ServiceModel service) isSelected;
  final ValueChanged<ServiceModel> onToggle;
  final ValueChanged<ServiceModel> onShowDetails;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: PageStorageKey('services-$category'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 10, bottom: 24),
      itemCount: services.length,
      itemBuilder: (context, i) {
        final service = services[i];
        return SelectableServiceTile(
          key: ValueKey(service.id),
          service: service,
          selected: isSelected(service),
          onToggle: () => onToggle(service),
          onShowDetails: () => onShowDetails(service),
        );
      },
    );
  }
}

class _CatalogueSkeleton extends StatelessWidget {
  const _CatalogueSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CategoryChipBarSkeleton(),
          Divider(height: 1, thickness: 1, color: context.colorScheme.onSurface.withValues(alpha: 0.06)),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 5,
              itemBuilder: (_, _) => const ServiceRowSkeleton(showAction: true),
            ),
          ),
        ],
      ),
    );
  }
}
