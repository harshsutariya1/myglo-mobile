import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../shared/authentication/controllers/user_profile_provider.dart';
import '../../shared/authentication/models/user_role.dart';
import 'upload_post_screen.dart';
import 'widgets/bento_grid.dart';
import 'widgets/discovery_grid_view.dart';
import 'widgets/favourites_feed_view.dart';
import 'widgets/nearby_bento_view.dart';

/// Discover. Clients get two tabs: an inspiration grid of recent looks
/// ("For you") and posts from their saved providers ("Favourites").
/// Providers get a single page of looks posted near their business.
class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  static const double _toolbarHeight = 64;

  static void _openComposer(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const UploadPostScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userProfileProvider.select((p) => p.value?.role));
    final resolving = ref.watch(userProfileProvider.select((p) => p.isLoading && !p.hasValue));

    if (role == UserRole.provider) return const _ProviderDiscover();
    // Don't flash the client tabs at a provider while their profile loads.
    if (resolving) return const _ResolvingDiscover();
    return const _ClientDiscover();
  }
}

/// The pinned title bar shared by every Discover layout.
SliverAppBar _discoverAppBar(BuildContext context, {bool scrolled = false, PreferredSizeWidget? bottom}) {
  final scheme = context.colorScheme;
  return SliverAppBar(
    pinned: true,
    backgroundColor: scheme.surface,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    shape: scrolled ? Border(bottom: BorderSide(color: scheme.onSurface.withValues(alpha: 0.06))) : null,
    systemOverlayStyle: SystemUiOverlayStyle.dark,
    automaticallyImplyLeading: false,
    centerTitle: false,
    titleSpacing: 20,
    toolbarHeight: DiscoveryScreen._toolbarHeight,
    title: const _DiscoverTitle(),
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 12),
        child: _ShareLookButton(onPressed: () => DiscoveryScreen._openComposer(context)),
      ),
    ],
    bottom: bottom,
  );
}

class _ClientDiscover extends StatefulWidget {
  const _ClientDiscover();

  @override
  State<_ClientDiscover> createState() => _ClientDiscoverState();
}

class _ClientDiscoverState extends State<_ClientDiscover> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  static const double _switcherHeight = 64;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: _discoverAppBar(
              context,
              scrolled: innerBoxIsScrolled,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(_switcherHeight),
                child: _FeedSwitcher(controller: _tabController),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            DiscoveryGridView(onShareLook: () => DiscoveryScreen._openComposer(context)),
            FavouritesFeedView(onBrowseForYou: () => _tabController.animateTo(0)),
          ],
        ),
      ),
    );
  }
}

class _ProviderDiscover extends StatelessWidget {
  const _ProviderDiscover();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: NearbyBentoView(
        appBar: _discoverAppBar(context),
        appBarExtent: MediaQuery.paddingOf(context).top + DiscoveryScreen._toolbarHeight,
        onShareLook: () => DiscoveryScreen._openComposer(context),
      ),
    );
  }
}

class _ResolvingDiscover extends StatelessWidget {
  const _ResolvingDiscover();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [_discoverAppBar(context), const SliverBentoSkeleton()],
      ),
    );
  }
}

class _DiscoverTitle extends StatelessWidget {
  const _DiscoverTitle();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Discover',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.1,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          ExcludeSemantics(
            child: Image.asset(
              'assets/graphics/Underline.png',
              height: 10,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 4,
                width: 72,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareLookButton extends StatelessWidget {
  const _ShareLookButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Tooltip(
      message: 'Share a look',
      child: Material(
        color: scheme.onSurface,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onPressed();
          },
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 18, color: scheme.surface),
                const SizedBox(width: 4),
                Text(
                  'Post',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: scheme.surface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill-shaped segmented control. The thumb follows the swipe between tabs.
class _FeedSwitcher extends StatelessWidget {
  const _FeedSwitcher({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
        ),
        child: TabBar(
          controller: controller,
          indicator: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 2)),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          labelColor: scheme.onSurface,
          unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.5),
          labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Muli'),
          unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Muli'),
          tabs: const [
            Tab(text: 'For you'),
            Tab(text: 'Favourites'),
          ],
        ),
      ),
    );
  }
}
