import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/routing/app_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../provider_profiles/controllers/provider_services_controller.dart';
import '../../../provider_profiles/views/screens/add_service_screen.dart';
import '../../../schedule/controllers/provider_schedule_controller.dart';

/// What a provider still has to do before clients can book them.
class BookingSetupProgress {
  const BookingSetupProgress({required this.hasServices, required this.hasHours, required this.hasLocation});

  final bool hasServices;
  final bool hasHours;
  final bool hasLocation;

  int get done => [hasServices, hasHours, hasLocation].where((step) => step).length;

  static const int total = 3;

  bool get isComplete => done == total;
}

/// Null while any part is still loading (so the card doesn't flash in).
final bookingSetupProgressProvider = Provider.autoDispose<BookingSetupProgress?>((ref) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null || !user.isProvider) return null;
  final services = ref.watch(providerServicesProvider(user.rawUser.id)).value;
  final hours = ref.watch(ownWorkingHoursProvider).value;
  if (services == null || hours == null) return null;
  final profile = user.profile;
  return BookingSetupProgress(
    hasServices: services.isNotEmpty,
    hasHours: !hours.isEmpty,
    hasLocation: profile.coordinates != null && (profile.addressText?.trim() ?? '').isNotEmpty,
  );
});

/// Checklist shown on the appointments screen until the provider can take
/// bookings: services, working hours and business location.
class BookingSetupCard extends ConsumerWidget {
  const BookingSetupCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(bookingSetupProgressProvider);
    if (progress == null || progress.isComplete) return const SizedBox.shrink();
    final scheme = context.colorScheme;
    final fraction = progress.done / BookingSetupProgress.total;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary.withValues(alpha: 0.14), scheme.secondary.withValues(alpha: 0.08)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Get ready for bookings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: scheme.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${progress.done} of ${BookingSetupProgress.total} done · clients can book once these are set',
                      style: TextStyle(fontSize: 13, height: 1.35, color: scheme.onSurface.withValues(alpha: 0.62)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox.square(
                dimension: 52,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: fraction,
                      strokeWidth: 5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: scheme.surface,
                      color: scheme.secondary,
                    ),
                    Center(
                      child: Text(
                        '${(fraction * 100).round()}%',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: scheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SetupStep(
            done: progress.hasServices,
            title: 'Add a service',
            subtitle: 'What you offer, how long it takes and the price',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddServiceScreen())),
          ),
          _SetupStep(
            done: progress.hasHours,
            title: 'Set your working hours',
            subtitle: 'Clients can only pick times inside them',
            onTap: () => context.pushNamed(AppRoute.workingHours.name),
          ),
          _SetupStep(
            done: progress.hasLocation,
            title: 'Add your business location',
            subtitle: 'Where clients come to, or where you travel from',
            onTap: () => context.pushNamed(AppRoute.serviceArea.name),
          ),
        ],
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({required this.done, required this.title, required this.subtitle, required this.onTap});

  final bool done;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Semantics(
      button: !done,
      label: '$title, ${done ? 'done' : 'to do'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: done ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? AppTheme.success : scheme.surface,
                  border: done ? null : Border.all(color: scheme.onSurface.withValues(alpha: 0.2), width: 1.5),
                ),
                child: done ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: done ? scheme.onSurface.withValues(alpha: 0.45) : scheme.onSurface,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (!done)
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.58)),
                      ),
                  ],
                ),
              ),
              if (!done) Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withValues(alpha: 0.35)),
            ],
          ),
        ),
      ),
    );
  }
}
