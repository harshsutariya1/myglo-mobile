import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/location/device_location.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_update_banner.dart';
import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../../shared/bookings/controllers/booking_controllers.dart';
import '../../explore/models/provider_listing.dart';
import '../../provider_profile/views/widgets/section_states.dart';
import '../controllers/home_controller.dart';
import '../controllers/home_location_controller.dart';
import 'widgets/home_categories.dart';
import 'widgets/home_header.dart';
import 'widgets/home_location_picker.dart';
import 'widgets/home_no_salons.dart';
import 'widgets/home_provider_cards.dart';
import 'widgets/home_search_bar.dart';
import 'widgets/home_section_header.dart';
import 'widgets/next_appointment_card.dart';

/// The client's home: greeting, where they're looking (current location or a
/// city), search, their next appointment, category shortcuts and the
/// providers there.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const double _gutter = 20;

  /// Clears the floating tab bar.
  static const double _bottomInset = 110;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final feed = ref.watch(homeFeedProvider);

    Future<void> refresh() async {
      ref.invalidate(passiveLocationProvider);
      ref.invalidate(serviceCitiesProvider);
      ref.invalidate(homeFeedProvider);
      ref.invalidate(bookingListProvider(homeUpcomingBookingsKey));
      try {
        await ref.read(homeFeedProvider.future);
      } catch (_) {
        // Shown inline by the feed.
      }
    }

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: context.colorScheme.primary,
          onRefresh: refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(_gutter, 12, _gutter, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppUpdateBanner(margin: EdgeInsets.only(bottom: 16)),
                      HomeHeader(now: now),
                      const SizedBox(height: 12),
                      const Align(alignment: Alignment.centerLeft, child: HomeLocationButton()),
                      const SizedBox(height: 18),
                      const HomeSearchBar(),
                      HomeNextAppointment(now: now, padding: const EdgeInsets.only(top: 22)),
                      const SizedBox(height: 28),
                      const HomeSectionHeader(title: 'Browse by category'),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: HomeCategories(padding: EdgeInsets.symmetric(horizontal: _gutter - 6)),
              ),
              ..._feedSlivers(context, ref, feed),
              const SliverToBoxAdapter(child: SizedBox(height: _bottomInset)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _feedSlivers(BuildContext context, WidgetRef ref, AsyncValue<HomeFeed> feed) {
    void openProvider(ProviderListing listing) =>
        context.pushNamed(AppRoute.publicProviderProfile.name, pathParameters: {'id': listing.id});
    void openMap() => context.pushNamed(AppRoute.providersMap.name);

    // A retry after an error keeps the error until it settles, and a new
    // location keeps the old list until it loads: show both as loading. A
    // pull-to-refresh keeps the list in place instead.
    if (feed.isLoading && (feed.hasError || !feed.isRefreshing)) return const [_FeedSkeleton()];

    return switch (feed) {
      AsyncData(:final value) when value.providers.isEmpty => [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(_gutter, 32, _gutter, 0),
            sliver: SliverToBoxAdapter(child: HomeNoSalons(place: value.place)),
          ),
        ],
      AsyncData(:final value) => [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(_gutter, 32, _gutter, 14),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HomeSectionHeader(
                    title: switch (value.place) {
                      CityPlace(:final city) => 'Salons ${city.placePhrase}',
                      _ => 'Near you',
                    },
                    subtitle: value.showDistance ? 'Closest first' : 'Salons and independent stylists',
                    actionLabel: 'Map',
                    onAction: openMap,
                  ),
                  if (value.locationUnavailable) ...[
                    const SizedBox(height: 12),
                    _LocationUnavailableNotice(onRetry: () => ref.invalidate(passiveLocationProvider)),
                  ],
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: _gutter),
            sliver: SliverList.separated(
              itemCount: value.providers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) => NearbyProviderTile(
                listing: value.providers[index],
                showDistance: value.showDistance,
                onTap: () => openProvider(value.providers[index]),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 20),
            sliver: SliverToBoxAdapter(child: _MapButton(onPressed: openMap)),
          ),
        ],
      AsyncError(:final error) => [
          SliverToBoxAdapter(
            child: SectionErrorView(
              title: "Couldn't load salons",
              message: describeLoadError(error, subject: 'salons'),
              onRetry: () {
                ref.invalidate(serviceCitiesProvider);
                ref.invalidate(homeFeedProvider);
              },
            ),
          ),
        ],
      _ => const [_FeedSkeleton()],
    };
  }
}

/// The client chose their current location but the device didn't give one.
class _LocationUnavailableNotice extends StatelessWidget {
  const _LocationUnavailableNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppTheme.peach.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.location_searching_rounded, size: 18, color: scheme.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'We couldn’t get your location, so you’re seeing this city instead.',
              style: TextStyle(fontSize: 13, height: 1.35, color: scheme.onSurface.withValues(alpha: 0.75)),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: scheme.secondary,
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Center(
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.map_outlined, size: 18),
        label: const Text('Explore the map'),
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.15)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

/// Stand-in for the provider list while it loads.
class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Shimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(HomeScreen._gutter, 32, HomeScreen._gutter, 14),
              child: SkeletonText(style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900), widthFactor: 0.4),
            ),
            for (var i = 0; i < 4; i++)
              const Padding(
                padding: EdgeInsets.fromLTRB(HomeScreen._gutter, 0, HomeScreen._gutter, 14),
                child: NearbyProviderTileSkeleton(),
              ),
          ],
        ),
      ),
    );
  }
}
