import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../location/geo_point.dart';
import '../platform/system_bridge.dart';
import '../utils/app_logger.dart';
import '../widgets/snackbar_utils.dart';
import 'google/google_maps_links.dart';

/// Whether [openInMaps] has anything to show for [point] / [address].
bool canOpenInMaps({GeoPoint? point, String? address}) =>
    GoogleMapsLinks.place(point: point, address: address) != null;

/// Shows a place in the Google Maps app, or on Google Maps in the browser
/// when the app isn't installed. Uses [point] when there is one (exactly
/// where the pin is), otherwise searches for [address]. Shows a snackbar if
/// nothing can open it.
Future<void> openInMaps(BuildContext context, WidgetRef ref, {GeoPoint? point, String? address}) async {
  final link = GoogleMapsLinks.place(point: point, address: address);
  if (link == null) return;
  final opened = await ref
      .read(systemBridgeProvider)
      .openUrl(link.web, appUrl: link.iosApp, appPackage: GoogleMapsLinks.androidPackage);
  if (opened) return;
  AppLogger.w('Maps did not open', tag: 'Maps');
  if (context.mounted) context.showAppSnackBar("Couldn't open Maps on this device.", isError: true);
}
