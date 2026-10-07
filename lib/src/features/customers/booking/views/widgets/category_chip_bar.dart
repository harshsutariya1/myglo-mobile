import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/skeleton/skeletons.dart';

/// Geometry shared by [CategoryChipBar] and [CategoryChipBarSkeleton].
abstract final class CategoryChipMetrics {
  static const double height = 40;
  static const double spacing = 8;
  static const EdgeInsets padding = EdgeInsets.fromLTRB(20, 8, 20, 12);
  static const Duration animation = Duration(milliseconds: 220);
}

/// One category in the bar, with how many of its services are selected.
typedef CategoryChipData = ({String label, int selectedCount});

/// Horizontally scrolling category pills. The active pill is filled; any pill
/// with selected services carries a count badge so the client can see where
/// their picks are without switching categories.
///
/// The active pill is scrolled into view whenever [selectedIndex] changes, so
/// swiping between categories keeps the bar in sync.
class CategoryChipBar extends StatefulWidget {
  const CategoryChipBar({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<CategoryChipData> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<CategoryChipBar> createState() => _CategoryChipBarState();
}

class _CategoryChipBarState extends State<CategoryChipBar> {
  final _keys = <int, GlobalKey>{};

  GlobalKey _keyFor(int index) => _keys.putIfAbsent(index, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    // Opening on a later category (e.g. a preselected service) shouldn't
    // leave its pill off-screen.
    if (widget.selectedIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected(animate: false));
    }
  }

  @override
  void didUpdateWidget(CategoryChipBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
    }
  }

  void _revealSelected({bool animate = true}) {
    final chipContext = _keys[widget.selectedIndex]?.currentContext;
    if (chipContext == null || !chipContext.mounted) return;
    Scrollable.ensureVisible(
      chipContext,
      alignment: 0.5,
      duration: animate ? CategoryChipMetrics.animation : Duration.zero,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = CategoryChipMetrics.padding;
    return SizedBox(
      height: CategoryChipMetrics.height + padding.vertical,
      child: Row(
        children: [
          // Pinned so every category stays one tap away however far the
          // pills have scrolled.
          Padding(
            padding: EdgeInsets.fromLTRB(padding.left, padding.top, 0, padding.bottom),
            child: _CategoryMenuButton(
              categories: widget.categories,
              selectedIndex: widget.selectedIndex,
              onSelected: widget.onSelected,
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: padding.copyWith(left: CategoryChipMetrics.spacing),
              itemCount: widget.categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: CategoryChipMetrics.spacing),
              itemBuilder: (context, index) {
                final category = widget.categories[index];
                return _CategoryChip(
                  key: _keyFor(index),
                  label: category.label,
                  selectedCount: category.selectedCount,
                  active: index == widget.selectedIndex,
                  onTap: () => widget.onSelected(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Round button that drops down a menu of every category, with the active
/// one ticked and selection counts alongside.
class _CategoryMenuButton extends StatelessWidget {
  const _CategoryMenuButton({
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<CategoryChipData> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return PopupMenuButton<int>(
      tooltip: 'All categories',
      initialValue: selectedIndex,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: scheme.onSurface.withValues(alpha: 0.25),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      itemBuilder: (context) => [
        for (var i = 0; i < categories.length; i++)
          PopupMenuItem<int>(
            value: i,
            height: 46,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    categories[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: i == selectedIndex ? FontWeight.w800 : FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (categories[i].selectedCount > 0) ...[
                  const SizedBox(width: 8),
                  _CountBadge(count: categories[i].selectedCount),
                ],
                SizedBox(
                  width: 28,
                  child: i == selectedIndex
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: Icon(Icons.check_rounded, size: 18, color: scheme.secondary),
                        )
                      : null,
                ),
              ],
            ),
          ),
      ],
      child: Container(
        width: CategoryChipMetrics.height,
        height: CategoryChipMetrics.height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.onSurface.withValues(alpha: 0.12)),
        ),
        child: Icon(Icons.tune_rounded, size: 19, color: scheme.onSurface),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    super.key,
    required this.label,
    required this.selectedCount,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int selectedCount;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final foreground = active ? scheme.surface : scheme.onSurface.withValues(alpha: 0.75);
    final radius = BorderRadius.circular(CategoryChipMetrics.height / 2);

    return Semantics(
      button: true,
      selected: active,
      label: selectedCount > 0 ? '$label, $selectedCount selected' : label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: CategoryChipMetrics.animation,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: active ? scheme.onSurface : scheme.surface,
          borderRadius: radius,
          border: Border.all(
            color: active ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: CategoryChipMetrics.animation,
                    style: DefaultTextStyle.of(context).style.copyWith(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      color: foreground,
                    ),
                    child: Text(label),
                  ),
                  AnimatedSize(
                    duration: CategoryChipMetrics.animation,
                    curve: Curves.easeOutCubic,
                    child: selectedCount > 0
                        ? Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _CountBadge(count: selectedCount),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(10)),
      child: Text(
        '$count',
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, height: 1, color: scheme.onPrimary),
      ),
    );
  }
}

/// Placeholder pills shown while services load. Place under a [Shimmer].
class CategoryChipBarSkeleton extends StatelessWidget {
  const CategoryChipBarSkeleton({super.key});

  static const _widths = [64.0, 92.0, 76.0, 104.0];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CategoryChipMetrics.height + CategoryChipMetrics.padding.vertical,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: CategoryChipMetrics.padding,
        itemCount: _widths.length,
        separatorBuilder: (_, _) => const SizedBox(width: CategoryChipMetrics.spacing),
        itemBuilder: (_, index) => SkeletonBox(
          width: _widths[index],
          height: CategoryChipMetrics.height,
          borderRadius: CategoryChipMetrics.height / 2,
        ),
      ),
    );
  }
}
