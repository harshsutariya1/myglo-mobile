import 'package:flutter/material.dart';
import '../utils/app_logger.dart';

/// A [NavigatorObserver] that logs route transitions automatically.
class AppRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final routeName = route.settings.name ?? route.runtimeType.toString();
    final prevName = previousRoute?.settings.name ?? previousRoute?.runtimeType.toString();
    AppLogger.nav(
      routeName,
      from: prevName,
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    final routeName = route.settings.name ?? route.runtimeType.toString();
    final prevName = previousRoute?.settings.name ?? previousRoute?.runtimeType.toString();
    AppLogger.d(
      '🔙 Popped $routeName ➔ Back to $prevName',
      tag: 'Navigation',
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    final newName = newRoute?.settings.name ?? newRoute?.runtimeType.toString() ?? 'unknown';
    final oldName = oldRoute?.settings.name ?? oldRoute?.runtimeType.toString();
    AppLogger.nav(
      newName,
      from: oldName,
    );
  }
}
