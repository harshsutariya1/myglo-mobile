import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class BusinessToolsScreen extends StatelessWidget {
  const BusinessToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Banner(
        message: 'DEMO',
        location: BannerLocation.topEnd,
        color: context.colorScheme.primary,
        child: Scaffold(
          backgroundColor: context.colorScheme.surface,
          appBar: AppBar(
            backgroundColor: context.colorScheme.surface,
            elevation: 0,
            title: Text(
              'Business Tools',
              style: TextStyle(
                color: context.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.notifications_outlined, color: context.colorScheme.onSurface),
                onPressed: () {},
              ),
            ],
          ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatCard(context, 'Total Earnings', '\$1,240', Icons.attach_money, true)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard(context, 'Total Bookings', '24', Icons.calendar_month, false)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatCard(context, 'Profile Views', '156', Icons.visibility, false)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard(context, 'Rating', '4.8 ★', Icons.star, false)),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _buildActionItem(
              context: context,
              title: 'Manage Schedule',
              subtitle: 'Update your availability and working hours',
              icon: Icons.schedule,
              onTap: () {},
            ),
            const SizedBox(height: 16),
            _buildActionItem(
              context: context,
              title: 'Services & Pricing',
              subtitle: 'Add or modify your service offerings',
              icon: Icons.design_services,
              onTap: () {},
            ),
            const SizedBox(height: 16),
            _buildActionItem(
              context: context,
              title: 'Financials',
              subtitle: 'View payout history and manage bank details',
              icon: Icons.account_balance_wallet,
              onTap: () {},
            ),
            const SizedBox(height: 100), // Bottom navigation bar padding
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, bool highlight) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? context.colorScheme.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: highlight ? null : Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: (highlight ? context.colorScheme.primary : Colors.black).withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: highlight ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFFFF5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: highlight ? Colors.white : context.colorScheme.secondary,
              size: 20,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.white : context.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: highlight ? Colors.white.withValues(alpha: 0.9) : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(
            color: Colors.grey.shade100,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: context.colorScheme.secondary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
