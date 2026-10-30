import 'package:flutter/material.dart';

import '../../config/app_config.dart';

/// Whether there's room to show a list and its detail side by side (tablets,
/// a phone in landscape, a browser window).
bool isWideLayout(BuildContext context) => MediaQuery.sizeOf(context).width >= AppConfig.adminWideLayoutWidth;

/// A list with its selected item's detail beside it on wide screens. On
/// narrow screens only [list] shows; the caller opens the detail as its own
/// page instead (check [isWideLayout] when an item is tapped).
class AdaptiveListDetail extends StatelessWidget {
  const AdaptiveListDetail({
    super.key,
    required this.list,
    required this.detail,
    required this.placeholder,
    this.listWidth = 400,
  });

  final Widget list;

  /// The selected item's detail, or null when nothing is selected.
  final Widget? detail;

  /// Shown in the detail pane when nothing is selected.
  final Widget placeholder;

  final double listWidth;

  @override
  Widget build(BuildContext context) {
    if (!isWideLayout(context)) return list;
    final divider = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: listWidth, child: list),
        VerticalDivider(width: 1, thickness: 1, color: divider),
        Expanded(child: detail ?? placeholder),
      ],
    );
  }
}
