import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/geo.dart';
import '../../../discovery_feed/controllers/user_posts_controller.dart';
import '../../../providers/provider_profiles/controllers/provider_services_controller.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../shared/authentication/models/profile_model.dart';
import '../../favourites/views/favourite_button.dart';
import '../controllers/public_provider_profile_controller.dart';
import 'widgets/provider_about_tab.dart';
import 'widgets/provider_action_sheets.dart';
import 'widgets/provider_posts_tab.dart';
import 'widgets/provider_profile_header.dart';
import 'widgets/provider_services_tab.dart';
import 'widgets/section_states.dart';

/// Client-facing profile of a single provider, reached from a provider card
/// or directly via `/provider/:id`.
///
/// The header, services and posts each come from their own provider, so any
/// one of them can be loading, failed or empty without holding up the others.
class PublicProviderProfileScreen extends ConsumerStatefulWidget {
  const PublicProviderProfileScreen({super.key, required this.providerId});

  final String providerId;

  @override
  ConsumerState<PublicProviderProfileScreen> createState() => _PublicProviderProfileScreenState();
}

class _PublicProviderProfileScreenState extends ConsumerState<PublicProviderProfileScreen>
    with SingleTickerProviderStateMixin {
  static const double _coverHeight = 180;
  static const _tabs = ['Services', 'Posts', 'About'];

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this)..addListener(_onTabChanged);
  }

  int _shownTab = 0;

  // Switch content as soon as a tab is tapped rather than after the indicator
  // animation finishes.
  void _onTabChanged() {
    if (_tabController.index != _shownTab) {
      setState(() => _shownTab = _tabController.index);
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  String get _id => widget.providerId;

  Future<void> _refresh() async {
    ref.invalidate(publicProviderProfileProvider(_id));
    ref.invalidate(providerServicesProvider(_id));
    ref.invalidate(userPostsProvider(_id));
    // Wait for every section to settle. Failures are rendered (and already
    // reported) by the section that owns them, so they are not rethrown here.
    Future<void> settle(Future<Object?> future) => future.then((_) {}, onError: (Object _) {});
    await Future.wait([
      settle(ref.read(publicProviderProfileProvider(_id).future)),
      settle(ref.read(providerServicesProvider(_id).future)),
      settle(ref.read(userPostsProvider(_id).future)),
    ]);
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      // Opened directly (deep link) with nothing underneath.
      context.goNamed(AppRoute.customerHome.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(publicProviderProfileProvider(_id));
    final clientPoint = ref.watch(
      userProfileProvider.select((p) => p.value?.profile.coordinates?.coordinates),
    );
    final distanceKm = Geo.distanceKm(clientPoint, profileAsync.value?.coordinates?.coordinates);

    if (profileAsync case AsyncData(value: null)) {
      return _NotFoundView(onBack: _goBack);
    }

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: RefreshIndicator(
        color: context.colorScheme.primary,
        edgeOffset: _coverHeight,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: _coverHeight,
              backgroundColor: context.colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    onPressed: _goBack,
                  ),
                ),
              ),
              actions: [
                if (profileAsync.value case final provider?)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: FavouriteButton(providerId: provider.id, providerName: providerDisplayName(provider)),
                  ),
              ],
              flexibleSpace: const FlexibleSpaceBar(
                background: Image(
                  image: AssetImage('assets/images/myglo_cover.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: switch (profileAsync) {
                AsyncData(:final value?) => ProviderProfileHeader(
                  profile: value,
                  distanceKm: distanceKm,
                  onBookNow: () => _tabController.animateTo(0),
                  onContact: () => showProviderContactSheet(context, value),
                ),
                AsyncError(:final error) => SectionErrorView(
                  title: "Profile didn't load",
                  message: describeLoadError(error, subject: "this provider's profile"),
                  onRetry: () => ref.invalidate(publicProviderProfileProvider(_id)),
                ),
                _ => const ProviderProfileHeaderSkeleton(),
              },
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarHeader(
                background: context.colorScheme.surface,
                tabBar: _buildTabBar(context),
              ),
            ),
            ..._buildTabContent(profileAsync, distanceKm),
            SliverToBoxAdapter(
              child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTabContent(AsyncValue<ProfileModel?> profileAsync, double? distanceKm) {
    switch (_shownTab) {
      case 0:
        return [
          ProviderServicesTab(
            providerId: _id,
            onBook: (service) => showServiceBookingSheet(
              context,
              service: service,
              provider: profileAsync.value,
            ),
          ),
        ];
      case 1:
        return [ProviderPostsTab(providerId: _id)];
      default:
        return [
          ProviderAboutTab(
            profile: profileAsync,
            distanceKm: distanceKm,
            onRetry: () => ref.invalidate(publicProviderProfileProvider(_id)),
          ),
        ];
    }
  }

  Widget _buildTabBar(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      height: _TabBarHeader.barHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.12)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: scheme.tertiary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(24),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: scheme.secondary,
        unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.5),
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        splashBorderRadius: BorderRadius.circular(24),
        tabs: [for (final label in _tabs) Tab(text: label)],
      ),
    );
  }
}

class _TabBarHeader extends SliverPersistentHeaderDelegate {
  const _TabBarHeader({required this.tabBar, required this.background});

  static const double barHeight = 44;
  static const double _verticalPadding = 8;

  final Widget tabBar;
  final Color background;

  @override
  double get minExtent => barHeight + _verticalPadding * 2;

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: _verticalPadding),
        child: tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarHeader oldDelegate) =>
      tabBar != oldDelegate.tabBar || background != oldDelegate.background;
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        leading: BackButton(onPressed: onBack),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_outlined, size: 56, color: context.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Provider not found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: context.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This profile may have been removed, or the link is incorrect.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: context.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onBack,
                style: FilledButton.styleFrom(
                  backgroundColor: context.colorScheme.primary,
                  foregroundColor: context.colorScheme.onPrimary,
                ),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
