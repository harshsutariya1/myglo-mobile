import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../providers/provider_profiles/models/service_catalog.dart';
import '../../../explore/views/widgets/listing_widgets.dart';

/// Side-scrolling category shortcuts; each opens search for that category.
class HomeCategories extends StatelessWidget {
  const HomeCategories({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsets padding;

  static const double _itemWidth = 78;
  static const double _iconSize = 64;

  @override
  Widget build(BuildContext context) {
    final height = _iconSize + 10 + MediaQuery.textScalerOf(context).scale(34);
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: ServiceCatalog.categorySuggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) => _CategoryItem(category: ServiceCatalog.categorySuggestions[index]),
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Semantics(
      button: true,
      label: 'Search $category',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          context.pushNamed(AppRoute.providerSearch.name, queryParameters: {'q': category});
        },
        child: SizedBox(
          width: HomeCategories._itemWidth,
          child: Column(
            children: [
              Container(
                width: HomeCategories._iconSize,
                height: HomeCategories._iconSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.peach.withValues(alpha: 0.42),
                      AppTheme.primaryPink.withValues(alpha: 0.16),
                    ],
                  ),
                  border: Border.all(color: AppTheme.primaryPink.withValues(alpha: 0.14)),
                ),
                child: Icon(serviceCategoryIcon(category), size: 26, color: scheme.secondary),
              ),
              const SizedBox(height: 8),
              Text(
                category,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
