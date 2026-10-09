
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/shared/authentication/models/auth_repository.dart';
import '../../features/shared/authentication/views/screens/email_auth_screen.dart';
import '../../features/shared/authentication/views/screens/email_confirmation_screen.dart';
import '../../features/shared/authentication/views/screens/role_selection_screen.dart';
import '../../features/shared/authentication/views/screens/onboarding_details_screen.dart';
import '../../features/shared/authentication/models/user_role.dart';
import '../../features/shared/authentication/views/screens/splash_screen.dart';
import '../../features/shared/authentication/views/screens/intro_screen.dart';
import '../services/app_preferences.dart';
import '../widgets/error_screen.dart';

import '../../features/customers/home/views/home_screen.dart';
import '../../features/providers/home/views/provider_home_screen.dart';
import '../../features/customers/bookings/views/bookings_screen.dart';
import '../../features/providers/business_tools/views/business_tools_screen.dart';
import '../../features/customers/customer_profile/views/customer_profile_screen.dart';
import '../../features/providers/provider_profiles/views/screens/profile_screen.dart';
import '../../features/providers/provider_profiles/views/screens/settings_screen.dart';
import '../../features/providers/provider_profiles/views/screens/cover_photos_screen.dart';
import '../../features/providers/provider_profiles/views/screens/edit_provider_profile_screen.dart';
import '../../features/providers/location/views/business_location_screen.dart';
import '../../features/customers/explore/views/provider_search_screen.dart';
import '../../features/customers/explore/views/providers_map_screen.dart';
import '../../features/discovery_feed/views/discovery_screen.dart';
import '../../features/customers/provider_profile/views/public_provider_profile_screen.dart';
import '../../features/customers/booking/views/select_services_screen.dart';
import '../../features/customers/booking/views/select_date_time_screen.dart';
import '../../features/customers/booking/views/booking_location_screen.dart';
import '../../features/customers/booking/views/booking_review_screen.dart';
import '../../features/customers/booking/views/booking_payment_screen.dart';
import '../../features/customers/booking/views/booking_confirmed_screen.dart';
import '../../features/customers/bookings/views/client_booking_detail_screen.dart';
import '../../features/providers/home/views/provider_booking_detail_screen.dart';
import '../../features/providers/schedule/views/service_area_screen.dart';
import '../../features/providers/schedule/views/time_off_screen.dart';
import '../../features/providers/schedule/views/working_hours_screen.dart';
import '../../features/shared/bookings/models/booking.dart';
import '../../features/shared/notifications/views/notifications_screen.dart';

import '../../features/shared/authentication/controllers/user_profile_provider.dart';
import '../widgets/main_scaffold.dart';
import 'app_route_observer.dart';
import 'app_router_guard.dart';

/// Query parameter of [AppRoute.selectServices] naming a service to start
/// with already selected.
const selectServicesInitialServiceParam = 'service';

/// Defines all the route names and paths in the app.
enum AppRoute {
  splash(path: '/'),
  intro(path: '/intro'),
  error(path: '/error'),
  auth(path: '/auth'),
  confirmEmail(path: '/confirm_email'),
  roleSelection(path: '/role'),
  onboardingDetails(path: '/onboarding_details'),
  customerHome(path: '/customer_home'),
  providerHome(path: '/provider_home'),
  discover(path: '/discover'),
  bookings(path: '/bookings'),
  businessTools(path: '/business_tools'),
  customerProfile(path: '/customer_profile'),
  providerProfile(path: '/provider_profile'),
  publicProviderProfile(path: '/provider/:id'),
  selectServices(path: 'book'),
  // The rest of the booking flow, nested so each step stacks on the last.
  selectDateTime(path: 'time'),
  bookingLocation(path: 'location'),
  bookingReview(path: 'review'),
  bookingPayment(path: 'payment'),
  bookingConfirmed(path: '/booking-confirmed/:bookingId'),
  clientBookingDetail(path: '/booking/:bookingId'),
  providerBookingDetail(path: '/appointments/:bookingId'),
  notifications(path: '/notifications'),
  settings(path: 'settings'),
  // Client discovery, full-screen over the home tab.
  providerSearch(path: '/search'),
  providersMap(path: '/map'),
  // Provider availability editors: full-screen, outside the tab shell, so
  // their save bar isn't covered by the tab bar.
  workingHours(path: '/schedule/working-hours'),
  timeOff(path: '/schedule/time-off'),
  serviceArea(path: '/schedule/service-area'),
  // Provider business profile editors, full-screen for the same reason.
  editProviderProfile(path: '/business/profile'),
  coverPhotos(path: '/business/cover-photos'),
  businessLocation(path: '/business/location');

  final String path;
  const AppRoute({required this.path});
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoute.splash.path,
    observers: [AppRouteObserver()],
    redirect: (context, state) => appRouterRedirect(context, state, ref),
    routes: [
      GoRoute(
        path: AppRoute.splash.path,
        name: AppRoute.splash.name,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoute.intro.path,
        name: AppRoute.intro.name,
        builder: (context, state) => const IntroScreen(),
      ),
      GoRoute(
        path: AppRoute.error.path,
        name: AppRoute.error.name,
        builder: (context, state) => const ErrorScreen(),
      ),
      GoRoute(
        path: AppRoute.auth.path,
        name: AppRoute.auth.name,
        builder: (context, state) => const EmailAuthScreen(),
      ),
      GoRoute(
        path: AppRoute.confirmEmail.path,
        name: AppRoute.confirmEmail.name,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return EmailConfirmationScreen(
            email: extra['email'] as String? ?? '',
            verifyOnly: extra['verifyOnly'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: AppRoute.roleSelection.path,
        name: AppRoute.roleSelection.name,
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          final id = state.uri.queryParameters['id'] ?? '';
          return RoleSelectionScreen(email: email, id: id);
        },
      ),
      GoRoute(
        path: AppRoute.onboardingDetails.path,
        name: AppRoute.onboardingDetails.name,
        builder: (context, state) {
          final profile = ref.read(userProfileProvider).value;
          final role = profile?.role ?? UserRole.customer;
          return OnboardingDetailsScreen(role: role);
        },
      ),
      // Full-screen (outside the tab shell) so it stacks over whichever tab
      // opened it and works as a standalone deep-link target.
      GoRoute(
        path: AppRoute.publicProviderProfile.path,
        name: AppRoute.publicProviderProfile.name,
        builder: (context, state) => PublicProviderProfileScreen(
          providerId: state.pathParameters['id']!,
        ),
        routes: [
          // `/provider/:id/book`: client-only through the same prefix guard.
          GoRoute(
            path: AppRoute.selectServices.path,
            name: AppRoute.selectServices.name,
            builder: (context, state) => SelectServicesScreen(
              providerId: state.pathParameters['id']!,
              initialServiceId: state.uri.queryParameters[selectServicesInitialServiceParam],
            ),
            routes: [
              GoRoute(
                path: AppRoute.selectDateTime.path,
                name: AppRoute.selectDateTime.name,
                builder: (context, state) => SelectDateTimeScreen(providerId: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: AppRoute.bookingLocation.path,
                    name: AppRoute.bookingLocation.name,
                    builder: (context, state) => BookingLocationScreen(providerId: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: AppRoute.bookingReview.path,
                        name: AppRoute.bookingReview.name,
                        builder: (context, state) => BookingReviewScreen(providerId: state.pathParameters['id']!),
                        routes: [
                          GoRoute(
                            path: AppRoute.bookingPayment.path,
                            name: AppRoute.bookingPayment.name,
                            builder: (context, state) =>
                                BookingPaymentScreen(providerId: state.pathParameters['id']!),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Booking and notification pages, full-screen over whichever tab opened
      // them (and deep-link targets for notifications).
      GoRoute(
        path: AppRoute.bookingConfirmed.path,
        name: AppRoute.bookingConfirmed.name,
        builder: (context, state) => BookingConfirmedScreen(
          bookingId: state.pathParameters['bookingId']!,
          initial: state.extra is Booking ? state.extra as Booking : null,
        ),
      ),
      GoRoute(
        path: AppRoute.clientBookingDetail.path,
        name: AppRoute.clientBookingDetail.name,
        builder: (context, state) => ClientBookingDetailScreen(bookingId: state.pathParameters['bookingId']!),
      ),
      GoRoute(
        path: AppRoute.providerBookingDetail.path,
        name: AppRoute.providerBookingDetail.name,
        builder: (context, state) => ProviderBookingDetailScreen(bookingId: state.pathParameters['bookingId']!),
      ),
      GoRoute(
        path: AppRoute.notifications.path,
        name: AppRoute.notifications.name,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoute.workingHours.path,
        name: AppRoute.workingHours.name,
        builder: (context, state) => const WorkingHoursScreen(),
      ),
      GoRoute(
        path: AppRoute.timeOff.path,
        name: AppRoute.timeOff.name,
        builder: (context, state) => const TimeOffScreen(),
      ),
      GoRoute(
        path: AppRoute.serviceArea.path,
        name: AppRoute.serviceArea.name,
        builder: (context, state) => const ServiceAreaScreen(),
      ),
      GoRoute(
        path: AppRoute.editProviderProfile.path,
        name: AppRoute.editProviderProfile.name,
        builder: (context, state) => const EditProviderProfileScreen(),
      ),
      GoRoute(
        path: AppRoute.coverPhotos.path,
        name: AppRoute.coverPhotos.name,
        builder: (context, state) => const CoverPhotosScreen(),
      ),
      GoRoute(
        path: AppRoute.businessLocation.path,
        name: AppRoute.businessLocation.name,
        builder: (context, state) => const BusinessLocationScreen(),
      ),
      GoRoute(
        path: AppRoute.providerSearch.path,
        name: AppRoute.providerSearch.name,
        builder: (context, state) => ProviderSearchScreen(initialQuery: state.uri.queryParameters['q']),
      ),
      GoRoute(
        path: AppRoute.providersMap.path,
        name: AppRoute.providersMap.name,
        builder: (context, state) => const ProvidersMapScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoute.customerHome.path,
            name: AppRoute.customerHome.name,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoute.providerHome.path,
            name: AppRoute.providerHome.name,
            builder: (context, state) => const ProviderHomeScreen(),
          ),
          GoRoute(
            path: AppRoute.discover.path,
            name: AppRoute.discover.name,
            builder: (context, state) => const DiscoveryScreen(),
          ),
          GoRoute(
            path: AppRoute.bookings.path,
            name: AppRoute.bookings.name,
            builder: (context, state) => const BookingsScreen(),
          ),
          GoRoute(
            path: AppRoute.businessTools.path,
            name: AppRoute.businessTools.name,
            builder: (context, state) => const BusinessToolsScreen(),
          ),
          GoRoute(
            path: AppRoute.customerProfile.path,
            name: AppRoute.customerProfile.name,
            builder: (context, state) => const CustomerProfileScreen(),
          ),
          GoRoute(
            path: AppRoute.providerProfile.path,
            name: AppRoute.providerProfile.name,
            builder: (context, state) => const ProfileScreen(),
            routes: [
              GoRoute(
                path: AppRoute.settings.path,
                name: AppRoute.settings.name,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.listen(authStateProvider, (_, next) {
    // Anyone who has signed in on this device is past the intro, including
    // installs from before the flag existed.
    if (next.value?.session != null) ref.read(introSeenProvider.notifier).markSeen();
    router.refresh();
  });
  ref.listen(userProfileProvider, (_, _) => router.refresh());

  return router;
});
