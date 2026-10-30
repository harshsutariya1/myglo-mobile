import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';

/// Platform configuration and the admin's own account.
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      (AppRoute.adminPlatformSettings, Icons.percent_rounded, 'Platform settings',
          'Myglo fee, fee-free period, cancellation defaults, card payment rules'),
      (AppRoute.adminCities, Icons.location_city_outlined, 'Service cities', 'Cities clients can browse, and their order'),
      (AppRoute.adminAuditLog, Icons.history, 'Audit log', 'Every change made by an admin'),
      (AppRoute.adminSecurity, Icons.verified_user_outlined, 'Your admin account', 'Two-factor and session'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final (route, icon, title, subtitle) in items)
            ListTile(
              leading: Icon(icon),
              title: Text(title),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.goNamed(route.name),
            ),
        ],
      ),
    );
  }
}
