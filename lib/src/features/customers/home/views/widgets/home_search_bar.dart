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
          child: Material(
            color: scheme.primary,
            shape: const CircleBorder(),
            elevation: 0,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HapticFeedback.selectionClick();
                context.pushNamed(AppRoute.providersMap.name);
              },
              child: Ink(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primaryPink, AppTheme.burntOrange],
                  ),
                  boxShadow: [
                    BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6)),
                  ],
                ),
                child: const Icon(Icons.map_rounded, color: Colors.white, semanticLabel: 'Open map'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
