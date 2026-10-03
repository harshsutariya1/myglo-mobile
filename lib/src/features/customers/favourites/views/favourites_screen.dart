import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../../shared/authentication/models/profile_model.dart';
import '../../provider_profile/views/widgets/provider_profile_header.dart';
import '../../provider_profile/views/widgets/section_states.dart';
import '../controllers/favourites_controller.dart';

/// The client's saved providers, newest first. Tap to open a profile; tap the
/// heart or swipe to remove (with undo).
class FavouritesScreen extends ConsumerWidget {
  const FavouritesScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(favouritesProvider);
    try {
      await ref.read(favouriteProfilesProvider.future);
    } catch (_) {
      // Rendered below; already reported by the repository.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final favouritesAsync = ref.watch(favouritesProvider);
    final profilesAsync = ref.watch(favouriteProfilesProvider);
    final ids = favouritesAsync.value?.providerIds;
    final profiles = profilesAsync.value;
    final error = favouritesAsync.error ?? (profiles == null ? profilesAsync.error : null);

    final List<Widget> body;
    if (ids != null && ids.isEmpty) {
      body = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: _EmptyFavourites(onDiscover: () => context.goNamed(AppRoute.discover.name))),
        ),
      ];
    } else if (ids != null && profiles != null) {
      // Accounts that have since been deleted are skipped.
      final saved = [for (final id in ids) ?profiles[id]];
      body = [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              '${saved.length} saved ${saved.length == 1 ? 'provider' : 'providers'}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurface.withValues(alpha: 0.55)),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: saved.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _FavouriteCard(
              key: ValueKey(saved[index].id),
              provider: saved[index],
            ),
          ),
        ),
      ];
    } else if (error != null) {
      body = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: SectionErrorView(
              title: "Favourites didn't load",
              message: describeLoadError(error, subject: 'your favourites'),
              onRetry: () => ref.invalidate(favouritesProvider),
            ),
          ),
        ),
      ];
    } else {
      body = [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
          sliver: SliverList.separated(
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, _) => const Shimmer(child: _FavouriteCardSkeleton()),
          ),
        ),
      ];
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      body: RefreshIndicator.adaptive(
        onRefresh: () => _refresh(ref),
        color: scheme.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: scheme.surface,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              titleSpacing: 4,
              title: Text(
                'Favourites',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: scheme.onSurface),
              ),
            ),
            ...body,
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24)),
          ],
        ),
      ),
    );
  }
}

class _FavouriteCard extends ConsumerWidget {
  const _FavouriteCard({super.key, required this.provider});

  final ProfileModel provider;

  static const double _avatarSize = 60;

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final name = providerDisplayName(provider);
    final notifier = ref.read(favouritesProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await notifier.setFavourite(provider.id, favourite: false);
    if (!context.mounted) return;
    if (!ok) {
      context.showAppSnackBar("Couldn't remove $name. Please try again.", isError: true);
      return;
    }
    context.showAppSnackBar(
      '$name removed from favourites',
      action: SnackBarAction(
        label: 'Undo',
        textColor: context.colorScheme.primary,
        onPressed: () async {
          final restored = await notifier.setFavourite(provider.id, favourite: true);
          if (!restored) {
            messenger
              ..clearSnackBars()
              ..showSnackBar(SnackBar(content: Text("Couldn't restore $name. Please try again.")));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final name = providerDisplayName(provider);
    final address = provider.addressText?.trim() ?? '';
    final muted = scheme.onSurface.withValues(alpha: 0.55);

    return Dismissible(
      key: ValueKey('dismiss-${provider.id}'),
      direction: DismissDirection.endToStart,
      // The list rebuilds from state; never let Dismissible remove it itself.
      confirmDismiss: (_) async {
        await _remove(context, ref);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: AppTheme.destructive, borderRadius: BorderRadius.circular(20)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.heart_broken_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.pushNamed(AppRoute.publicProviderProfile.name, pathParameters: {'id': provider.id}),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              children: [
                _ProviderThumb(name: name, url: provider.profilePic, size: _avatarSize),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 15, color: muted),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              address.isNotEmpty ? address : 'Location not provided',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove from favourites',
                  onPressed: () => _remove(context, ref),
                  icon: Icon(Icons.favorite_rounded, color: scheme.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderThumb extends StatelessWidget {
  const _ProviderThumb({required this.name, required this.url, required this.size});

  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final fallback = Container(
      color: scheme.primary,
      alignment: Alignment.center,
      child: Text(
        name.characters.first.toUpperCase(),
        style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w800, color: scheme.onPrimary),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox.square(
        dimension: size,
        child: url == null
            ? fallback
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, _) => const Shimmer(child: SkeletonBox(borderRadius: 0)),
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class _FavouriteCardSkeleton extends StatelessWidget {
  const _FavouriteCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          SkeletonBox(width: _FavouriteCard._avatarSize, height: _FavouriteCard._avatarSize, borderRadius: 16),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700), widthFactor: 0.55),
                SizedBox(height: 4),
                SkeletonText(style: TextStyle(fontSize: 13), widthFactor: 0.8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFavourites extends StatelessWidget {
  const _EmptyFavourites({required this.onDiscover});

  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SectionEmptyView(
          icon: Icons.favorite_border_rounded,
          title: 'No favourites yet',
          message: "Tap the heart on a salon's profile to save it here for quick booking.",
        ),
        FilledButton(
          onPressed: onDiscover,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.onSurface,
            foregroundColor: scheme.surface,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          child: const Text('Discover salons'),
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}
