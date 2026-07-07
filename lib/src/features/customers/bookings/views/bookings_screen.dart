import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  bool _isUpcomingSelected = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Title with underline
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bookings',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: context.colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      // Mocking the sparkle adornment with an icon if there's no asset
                      Transform.translate(
                        offset: const Offset(4, -4),
                        child: Icon(
                          Icons.auto_awesome,
                          color: context.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  Transform.translate(
                    offset: const Offset(0, -6),
                    child: Image.asset(
                      'assets/graphics/Underline.png',
                      width: 130,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Custom Tab Switcher
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isUpcomingSelected = true),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isUpcomingSelected
                                ? context.colorScheme.tertiary.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Upcoming',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: _isUpcomingSelected ? FontWeight.w600 : FontWeight.w400,
                              color: _isUpcomingSelected ? context.colorScheme.secondary : Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isUpcomingSelected = false),
                        child: Container(
                          decoration: BoxDecoration(
                            color: !_isUpcomingSelected
                                ? context.colorScheme.tertiary.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Completed',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: !_isUpcomingSelected ? FontWeight.w600 : FontWeight.w400,
                              color: !_isUpcomingSelected ? context.colorScheme.secondary : Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Booking Cards
              if (_isUpcomingSelected) ...[
                _buildBookingCard(
                  dayOfWeek: 'FRI',
                  date: '26',
                  month: 'JUN',
                  providerName: 'Lily Lashes',
                  serviceName: 'Natural lash extension',
                  time: '1pm - 2pm',
                ),
                const SizedBox(height: 16),
                _buildBookingCard(
                  dayOfWeek: 'MON',
                  date: '29',
                  month: 'JUN',
                  providerName: 'Nails Nirvana',
                  serviceName: 'French manicure',
                  time: '10am - 11am',
                ),
                const SizedBox(height: 16),
                _buildBookingCard(
                  dayOfWeek: 'WED',
                  date: '26',
                  month: 'JUN',
                  providerName: 'Korea Beauty',
                  serviceName: 'Natural lash extension',
                  time: '5pm - 6pm',
                ),
              ] else ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: Text(
                      'No completed bookings yet.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 100), // Bottom navigation bar padding
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard({
    required String dayOfWeek,
    required String date,
    required String month,
    required String providerName,
    required String serviceName,
    required String time,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Date Box
          Container(
            width: 70,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dayOfWeek,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  month,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.grey.shade300,
                      child: Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      providerName,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  serviceName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 13,
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
