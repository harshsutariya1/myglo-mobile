import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen> {
  int _selectedTabIndex = 0;

  final List<Map<String, dynamic>> _upcomingAppointments = [
    {
      'date': 'WED\n12\nMAY',
      'avatar': 'assets/images/avatars/avatar_1.png',
      'name': 'Michelle Zhang',
      'service': 'Natural lash extension',
      'time': '1pm - 2pm',
    },
    {
      'date': 'TUES\n11\nMAY',
      'avatar': 'assets/images/avatars/avatar_2.png',
      'name': 'Jane Doe',
      'service': 'Wispy lash extension',
      'time': '1pm - 2pm',
    },
    {
      'date': 'MON\n10\nMAY',
      'avatar': 'assets/images/avatars/avatar_3.png',
      'name': 'Eileen Lo',
      'service': 'Volume lash extension',
      'time': '1pm - 2pm',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Banner(
        message: 'DEMO',
        location: BannerLocation.topEnd,
        color: AppTheme.primaryPink,
        child: Scaffold(
          backgroundColor: AppTheme.white,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Flexible(
                              child: Text(
                                'My appointments',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 24),
                          child: Image.asset(
                            'assets/graphics/Underline.png',
                            width: 200,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: AppTheme.darkRed, size: 28),
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Profile completion card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F5), // Light pinkish background
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Complete your profile',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkRed,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '0 of 4 tasks completed',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const CircularProgressIndicator(
                            value: 0.75,
                            backgroundColor: Colors.white,
                            color: AppTheme.burntOrange,
                            strokeWidth: 6,
                          ),
                          Center(
                            child: const Text(
                              '75%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.darkRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Segmented control
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTabIndex = 0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _selectedTabIndex == 0 ? const Color(0xFFFFF5F5) : Colors.transparent,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Upcoming',
                            style: TextStyle(
                              color: _selectedTabIndex == 0 ? AppTheme.burntOrange : Colors.grey.shade500,
                              fontWeight: _selectedTabIndex == 0 ? FontWeight.bold : FontWeight.normal,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedTabIndex = 1),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _selectedTabIndex == 1 ? const Color(0xFFFFF5F5) : Colors.transparent,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Completed',
                            style: TextStyle(
                              color: _selectedTabIndex == 1 ? AppTheme.burntOrange : Colors.grey.shade500,
                              fontWeight: _selectedTabIndex == 1 ? FontWeight.bold : FontWeight.normal,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // List
              ..._upcomingAppointments.map((appt) => _buildAppointmentCard(appt)),
              const SizedBox(height: 100),
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appt) {
    List<String> dateParts = appt['date'].toString().split('\n');
    String dayOfWeek = dateParts.isNotEmpty ? dateParts[0] : '';
    String dayOfMonth = dateParts.length > 1 ? dateParts[1] : '';
    String month = dateParts.length > 2 ? dateParts[2] : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Date box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  dayOfWeek,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  dayOfMonth,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkRed,
                  ),
                ),
                Text(
                  month,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundImage: AssetImage(appt['avatar']),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      appt['name'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  appt['service'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkRed,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  appt['time'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
