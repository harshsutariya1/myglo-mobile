import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../providers/provider_profiles/models/service_catalog.dart';
import '../../provider_profile/views/widgets/section_states.dart';
import '../controllers/provider_search_controller.dart';
import '../models/provider_listing.dart';
import 'widgets/listing_widgets.dart';

/// Hero tag shared with the search bar on the client home screen, so the bar
/// grows into this screen's search field.
const providerSearchHeroTag = 'provider-search-field';

/// Client search: salons and independent providers by name, service,
/// category or suburb, with recent searches and category shortcuts before
/// anything is typed.
class ProviderSearchScreen extends ConsumerStatefulWidget {
  const ProviderSearchScreen({super.key, this.initialQuery});

  /// Pre-filled text (e.g. a category tapped elsewhere).
  final String? initialQuery;

  @override
  ConsumerState<ProviderSearchScreen> createState() => _ProviderSearchScreenState();
}

class _ProviderSearchScreenState extends ConsumerState<ProviderSearchScreen> {
  late final TextEditingController _text = TextEditingController(text: widget.initialQuery ?? '');
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery?.trim() ?? '';
    if (initial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(providerSearchProvider.notifier).submit(initial);
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _search(String query, {bool remember = true}) {
    _text.value = TextEditingValue(text: query, selection: TextSelection.collapsed(offset: query.length));
    _focus.unfocus();
    ref.read(providerSearchProvider.notifier).submit(query);
    if (remember) ref.read(recentSearchesProvider.notifier).add(query);
  }

  void _clear() {
    _text.clear();
    ref.read(providerSearchProvider.notifier).setQuery('');
    _focus.requestFocus();
  }

  void _open(ProviderListing listing) {
    final query = ref.read(providerSearchProvider).query;
    ref.read(recentSearchesProvider.notifier).add(query);
    _focus.unfocus();
    context.pushNamed(AppRoute.publicProviderProfile.name, pathParameters: {'id': listing.id});
  }

  void _openMap() {
    _focus.unfocus();
    context.pushNamed(AppRoute.providersMap.name);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final state = ref.watch(providerSearchProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Hero(
                      tag: providerSearchHeroTag,
                      flightShuttleBuilder: searchHeroShuttle,
                      child: _SearchField(
                        controller: _text,
                        focusNode: _focus,
                        onChanged: (value) {
                          setState(() {});
                          ref.read(providerSearchProvider.notifier).setQuery(value);
                        },
                        onSubmitted: (value) => _search(value),
                        onClear: _clear,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: state.isIdle
                    ? _Suggestions(
                        key: const ValueKey('suggestions'),
                        onSearch: _search,
                        onOpenMap: _openMap,
                      )
                    : _Results(
                        key: const ValueKey('results'),
                        state: state,
                        onOpen: _open,
                        onOpenMap: _openMap,
                        onRetry: () => ref.read(providerSearchProvider.notifier).retry(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What flies between the home search bar and this screen's field: a static
/// look-alike, so the real text field (and its focus) never exists twice.
Widget searchHeroShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromContext,
  BuildContext toContext,
) =>
    const SearchPill();

/// The search bar at rest: a rounded pill with the prompt. Also used as the
/// tappable search bar on the client home screen.
class SearchPill extends StatelessWidget {
  const SearchPill({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Material(
      color: scheme.onSurface.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(Icons.search_rounded, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Salons, services or suburbs',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Material(
      color: scheme.onSurface.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(28),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        textCapitalization: TextCapitalization.none,
        inputFormatters: [LengthLimitingTextInputFormatter(80)],
        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: scheme.onSurface),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          hintText: 'Salons, services or suburbs',
          hintStyle: TextStyle(fontWeight: FontWeight.w500, color: scheme.onSurface.withValues(alpha: 0.4)),
          prefixIcon: Icon(Icons.search_rounded, color: scheme.primary),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  icon: Icon(Icons.cancel_rounded, size: 20, color: scheme.onSurface.withValues(alpha: 0.35)),
                ),
        ),
      ),
    );
  }
}

/// Recent searches, categories and a way into the map.
class _Suggestions extends ConsumerWidget {
  const _Suggestions({super.key, required this.onSearch, required this.onOpenMap});

  final void Function(String query, {bool remember}) onSearch;
  final VoidCallback onOpenMap;

  static IconData _categoryIcon(String category) => switch (category.toLowerCase()) {
        'hair' => Icons.content_cut_rounded,
        'colour' => Icons.palette_outlined,
        'nails' => Icons.back_hand_outlined,
        'lashes & brows' => Icons.visibility_outlined,
        'makeup' => Icons.brush_outlined,
        'skin & facials' => Icons.face_retouching_natural_outlined,
        'waxing' => Icons.spa_outlined,
        'massage' => Icons.self_improvement_rounded,
        _ => Icons.auto_awesome_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final recent = ref.watch(recentSearchesProvider);
    final muted = scheme.onSurface.withValues(alpha: 0.5);

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + MediaQuery.paddingOf(context).bottom),
      children: [
        _MapBanner(onTap: onOpenMap),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(child: _SectionLabel('Recent searches')),
              TextButton(
                onPressed: () => ref.read(recentSearchesProvider.notifier).clear(),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.secondary,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                child: const Text('Clear'),
              ),
            ],
          ),
          for (final query in recent)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSearch(query),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 20, color: muted),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        query,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ref.read(recentSearchesProvider.notifier).remove(query),
                      icon: Icon(Icons.close_rounded, size: 18, color: muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 26),
        _SectionLabel('Browse by category'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final category in ServiceCatalog.categorySuggestions)
              ActionChip(
                avatar: Icon(_categoryIcon(category), size: 18, color: scheme.secondary),
                label: Text(category),
                onPressed: () => onSearch(category),
                labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onSurface),
                backgroundColor: scheme.surface,
                side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.1)),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              ),
          ],
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
          color: context.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _MapBanner extends StatelessWidget {
  const _MapBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Material(
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.peach.withValues(alpha: 0.55),
              AppTheme.primaryPink.withValues(alpha: 0.28),
            ],
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: scheme.primary.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Icon(Icons.map_rounded, color: scheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Explore on the map',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: scheme.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'See salons and stylists near you',
                        style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.65)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withValues(alpha: 0.45)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    super.key,
    required this.state,
    required this.onOpen,
    required this.onOpenMap,
    required this.onRetry,
  });

  final ProviderSearchState state;
  final ValueChanged<ProviderListing> onOpen;
  final VoidCallback onOpenMap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final bottom = 24 + MediaQuery.paddingOf(context).bottom;

    return switch (state.results) {
      AsyncData(:final value) when value.isEmpty => ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(8, 24, 8, bottom),
          children: [
            SectionEmptyView(
              icon: Icons.search_off_rounded,
              title: 'No matches for “${state.query}”',
              message: 'Try a service like “gel nails”, a salon name or a suburb.',
            ),
            Center(
              child: OutlinedButton.icon(
                onPressed: onOpenMap,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Explore the map'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onSurface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      AsyncData(:final value) => ListView.separated(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
          itemCount: value.length + 1,
          separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 10 : 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '${value.length} ${value.length == 1 ? 'result' : 'results'}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface.withValues(alpha: 0.5)),
                ),
              );
            }
            final listing = value[index - 1];
            return ProviderResultCard(listing: listing, query: state.query, onTap: () => onOpen(listing));
          },
        ),
      AsyncError(:final error) => ListView(
          padding: EdgeInsets.fromLTRB(8, 24, 8, bottom),
          children: [
            SectionErrorView(
              title: "Search didn't work",
              message: describeLoadError(error, subject: 'search results'),
              onRetry: onRetry,
            ),
          ],
        ),
      _ => ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) => const ProviderResultSkeleton(),
        ),
    };
  }
}
