import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../explore/views/provider_search_screen.dart';

/// The client home's search entry: tapping the bar opens search (the bar
/// grows into its field), and the map button opens providers on the map.
class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Search salons, services or suburbs',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                context.pushNamed(AppRoute.providerSearch.name);
              },
              child: const Hero(
                tag: providerSearchHeroTag,
                flightShuttleBuilder: searchHeroShuttle,
                child: SearchPill(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: 'Map',
          // The glow sits outside the Material: painted on its ink layer it
          // gets cropped to a square.
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6)),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primaryPink, AppTheme.burntOrange],
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.pushNamed(AppRoute.providersMap.name);
                  },
                  child: const Icon(Icons.map_rounded, color: Colors.white, semanticLabel: 'Open map'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
