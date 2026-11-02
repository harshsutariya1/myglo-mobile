import 'package:flutter/foundation.dart' show ValueKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../features/shared/account_deletion/views/delete_account_screen.dart';
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
import '../../features/providers/business_tools/views/contacts_screen.dart';
import '../../features/customers/customer_profile/views/customer_profile_screen.dart';
import '../../features/providers/provider_profiles/views/screens/profile_screen.dart';
import '../../features/providers/provider_profiles/views/screens/settings_screen.dart';
import '../../features/providers/provider_profiles/views/screens/cover_photos_screen.dart';
import '../../features/providers/provider_profiles/views/screens/edit_provider_profile_screen.dart';
import '../../features/providers/location/views/business_location_screen.dart';
import '../../features/providers/payments/views/financials_screen.dart';
import '../../features/providers/payments/views/payments_setup_screen.dart';
import '../../features/customers/explore/views/provider_search_screen.dart';
import '../../features/customers/explore/views/providers_map_screen.dart';
import '../../features/discovery_feed/views/discovery_screen.dart';
import '../../features/discovery_feed/views/shared_post_screen.dart';
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

import '../../features/admin/controllers/admin_controllers.dart' show AuditFilter;
import '../../features/admin/models/admin_models.dart';
import '../../features/admin/views/admin_home_screen.dart';
import '../../features/admin/views/admin_moderation_screen.dart';
import '../../features/admin/views/admin_payment_detail_screen.dart';
import '../../features/admin/views/admin_payments_screen.dart';
import '../../features/admin/views/admin_people_screen.dart';
import '../../features/admin/views/admin_security_screen.dart';
import '../../features/admin/views/admin_settings_screen.dart';
import '../../features/admin/views/admin_shell.dart';
import '../../features/admin/views/admin_user_detail_screen.dart';
import '../../features/admin/views/admin_verify_screen.dart';
import '../../features/admin/views/audit_log_screen.dart';
import '../../features/admin/views/platform_settings_screen.dart';
import '../../features/admin/views/service_cities_screen.dart';
import '../../features/admin/views/service_city_editor_screen.dart';
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
  // A post opened from a shared link (https://myglo.app/p/<id>).
  sharedPost(path: '/p/:id'),
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
  // Clients and providers alike, full-screen over their settings.
  deleteAccount(path: '/account/delete'),
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
  businessLocation(path: '/business/location'),
  // The provider's clients, full-screen over Business Tools.
  providerContacts(path: '/business/contacts'),
  // Card payments and payouts (Stripe), full-screen.
  providerPayments(path: '/business/payments'),
  providerEarnings(path: 'earnings'),
  // Admin accounts only (see isAdminOnlyPath). Two-factor comes first; the
  // rest lives in the admin shell.
  adminVerify(path: '/admin-verify'),
  adminHome(path: '/admin'),
  adminPeople(path: '/admin/people'),
  adminUser(path: ':userId'),
  adminPayments(path: '/admin/payments'),
  adminPayment(path: 'booking/:bookingId'),
  adminModeration(path: '/admin/moderation'),
  adminSettings(path: '/admin/settings'),
  adminPlatformSettings(path: 'platform'),
  adminCities(path: 'cities'),
  adminCityEditor(path: 'edit'),
  adminAuditLog(path: 'audit'),
  adminSecurity(path: 'security');

  final String path;
  const AppRoute({required this.path});
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoute.splash.path,
    // Sentry's observer adds navigation breadcrumbs and screen-load traces.
    observers: [AppRouteObserver(), SentryNavigatorObserver()],
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
      // Shared post links, for clients and providers alike.
      GoRoute(
        path: AppRoute.sharedPost.path,
        name: AppRoute.sharedPost.name,
        builder: (context, state) => SharedPostScreen(postId: state.pathParameters['id']!),
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
        path: AppRoute.deleteAccount.path,
        name: AppRoute.deleteAccount.name,
        builder: (context, state) => const DeleteAccountScreen(),
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
        path: AppRoute.providerContacts.path,
        name: AppRoute.providerContacts.name,
        builder: (context, state) => const ContactsScreen(),
      ),
      GoRoute(
        path: AppRoute.providerPayments.path,
        name: AppRoute.providerPayments.name,
        builder: (context, state) => const PaymentsSetupScreen(),
        routes: [
          GoRoute(
            path: AppRoute.providerEarnings.path,
            name: AppRoute.providerEarnings.name,
            builder: (context, state) => const FinancialsScreen(),
          ),
        ],
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
      GoRoute(
        path: AppRoute.adminVerify.path,
        name: AppRoute.adminVerify.name,
        builder: (context, state) => const AdminVerifyScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: AppRoute.adminHome.path,
            name: AppRoute.adminHome.name,
            builder: (context, state) => const AdminHomeScreen(),
          ),
          GoRoute(
            path: AppRoute.adminPeople.path,
            name: AppRoute.adminPeople.name,
            builder: (context, state) => AdminPeopleScreen(initialRole: state.uri.queryParameters['role']),
            routes: [
              GoRoute(
                path: AppRoute.adminUser.path,
                name: AppRoute.adminUser.name,
                builder: (context, state) => AdminUserDetailScreen(userId: state.pathParameters['userId']!),
              ),
            ],
          ),
          GoRoute(
            path: AppRoute.adminPayments.path,
            name: AppRoute.adminPayments.name,
            builder: (context, state) => const AdminPaymentsScreen(),
            routes: [
              GoRoute(
                path: AppRoute.adminPayment.path,
                name: AppRoute.adminPayment.name,
                builder: (context, state) => AdminPaymentDetailScreen(bookingId: state.pathParameters['bookingId']!),
              ),
            ],
          ),
          GoRoute(
            path: AppRoute.adminModeration.path,
            name: AppRoute.adminModeration.name,
            builder: (context, state) => const AdminModerationScreen(),
          ),
          GoRoute(
            path: AppRoute.adminSettings.path,
            name: AppRoute.adminSettings.name,
            builder: (context, state) => const AdminSettingsScreen(),
            routes: [
              GoRoute(
                path: AppRoute.adminPlatformSettings.path,
                name: AppRoute.adminPlatformSettings.name,
                builder: (context, state) => const PlatformSettingsScreen(),
              ),
              GoRoute(
                path: AppRoute.adminCities.path,
                name: AppRoute.adminCities.name,
                builder: (context, state) => const ServiceCitiesScreen(),
                routes: [
                  GoRoute(
                    path: AppRoute.adminCityEditor.path,
                    name: AppRoute.adminCityEditor.name,
                    builder: (context, state) => ServiceCityEditorScreen(city: state.extra as AdminServiceCity?),
                  ),
                ],
              ),
              GoRoute(
                path: AppRoute.adminAuditLog.path,
                name: AppRoute.adminAuditLog.name,
                builder: (context, state) => AuditLogScreen(
                  filter: AuditFilter(
                    targetType: state.uri.queryParameters['target_type'],
                    targetId: state.uri.queryParameters['target_id'],
                  ),
                ),
              ),
              GoRoute(
                path: AppRoute.adminSecurity.path,
                name: AppRoute.adminSecurity.name,
                builder: (context, state) => const AdminSecurityScreen(),
              ),
            ],
          ),
        ],
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
            builder: (context, state) {
              final tab = ProviderHomeTab.fromQuery(state.uri.queryParameters['tab']);
              // Keyed by tab so a link to another list switches to it.
              return ProviderHomeScreen(key: ValueKey(tab), initialTab: tab);
            },
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
