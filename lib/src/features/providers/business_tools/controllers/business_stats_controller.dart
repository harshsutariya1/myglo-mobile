import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../shared/bookings/controllers/booking_controllers.dart';
import '../../../shared/bookings/models/booking_failure.dart';
import '../models/business_stats.dart';
import '../models/business_stats_repository.dart';

/// The signed-in provider's numbers for this month. Refetches whenever one
/// of their bookings changes (completed, cash recorded…), so the overview
/// stays current while it's on screen.
final businessStatsProvider = FutureProvider.autoDispose<BusinessStats>((ref) async {
  ref.watch(bookingChangesProvider);
  // Waits for the profile (only rebuilding if the signed-in provider changes).
  final providerId = await ref.watch(
    userProfileProvider.selectAsync((p) => p?.isProvider == true ? p?.rawUser.id : null),
  );
  if (providerId == null) throw const BookingFailure(BookingFailureCode.providersOnly);
  return ref.watch(businessStatsRepositoryProvider).thisMonth();
});
