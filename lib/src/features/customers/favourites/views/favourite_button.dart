import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../controllers/favourites_controller.dart';
import 'favourites_screen.dart';

/// Round heart that saves a provider to the signed-in client's favourites.
/// Renders nothing for providers and signed-out viewers.
class FavouriteButton extends ConsumerWidget {
  const FavouriteButton({super.key, required this.providerId, required this.providerName});

  final String providerId;
  final String providerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favourites = ref.watch(favouritesProvider).value;
    if (favourites == null || !favourites.canFavourite) return const SizedBox.shrink();
    final saved = favourites.contains(providerId);

    Future<void> toggle() async {
      HapticFeedback.lightImpact();
      final ok = await ref.read(favouritesProvider.notifier).setFavourite(providerId, favourite: !saved);
      if (!context.mounted) return;
      if (!ok) {
        context.showAppSnackBar(
          saved ? "Couldn't remove $providerName. Please try again." : "Couldn't save $providerName. Please try again.",
          isError: true,
        );
      } else if (!saved) {
        context.showAppSnackBar(
          '$providerName saved to your favourites',
          action: SnackBarAction(
            label: 'View',
            textColor: context.colorScheme.primary,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FavouritesScreen()),
            ),
          ),
        );
      }
    }

    return Semantics(
      toggled: saved,
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
        child: IconButton(
          tooltip: saved ? 'Remove from favourites' : 'Save to favourites',
          onPressed: toggle,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: Icon(
              saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(saved),
              size: 20,
              color: saved ? context.colorScheme.primary : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
