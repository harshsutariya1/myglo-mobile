import '../../../shared/bookings/models/booking_time.dart';

/// One of the signed-in provider's clients (anyone who has booked with
/// them), with their booking totals, as computed by the
/// `get_provider_contacts` RPC.
class ProviderContact {
  const ProviderContact({
    required this.clientId,
    required this.name,
    required this.phone,
    required this.timeZone,
    required this.bookingCount,
    required this.completedCount,
    required this.upcomingCount,
    required this.totalPaidCents,
    required this.firstBookedAt,
    required this.lastStartsAt,
    this.avatarUrl,
    this.email,
    this.lastVisitLocal,
    this.nextStartsAtLocal,
  });

  final String clientId;

  /// As the client gave it on their most recent booking.
  final String name;
  final String? avatarUrl;

  /// As the client gave it on their most recent booking.
  final String phone;

  /// Only when the client has made their email public (null otherwise).
  final String? email;

  /// The provider's time zone on the client's most recent booking.
  final String timeZone;

  /// Every booking with the provider, whatever its outcome.
  final int bookingCount;

  /// Appointments that took place (marked completed).
  final int completedCount;

  /// Requests waiting for an answer and confirmed appointments still ahead.
  final int upcomingCount;

  /// Payments recorded as received, in AUD cents.
  final int totalPaidCents;

  /// When the client first booked (an instant).
  final DateTime firstBookedAt;

  /// Start of the client's latest appointment, past or upcoming (an
  /// instant). Contacts are listed by it, newest first.
  final DateTime lastStartsAt;

  /// Start of the client's latest completed appointment, as a provider-local
  /// wall clock (see [BookingTime]). Null before their first visit.
  final DateTime? lastVisitLocal;

  /// Start of the client's next request or confirmed appointment, as a
  /// provider-local wall clock. Null when nothing is coming up.
  final DateTime? nextStartsAtLocal;

  /// [name], or a stand-in if the client somehow left it blank.
  String get displayName => name.isEmpty ? 'Client' : name;

  bool get hasUpcoming => nextStartsAtLocal != null;

  factory ProviderContact.fromJson(Map<String, dynamic> json) {
    DateTime? wallClock(String key) {
      final value = json[key] as String?;
      return value == null ? null : BookingTime.parseWallClock(value);
    }

    return ProviderContact(
      clientId: json['client_id'] as String,
      name: (json['client_name'] as String?)?.trim() ?? '',
      avatarUrl: json['client_avatar_url'] as String?,
      phone: (json['client_phone'] as String?)?.trim() ?? '',
      email: switch ((json['client_email'] as String?)?.trim()) {
        final email? when email.isNotEmpty => email,
        _ => null,
      },
      timeZone: json['time_zone'] as String? ?? BookingTime.defaultTimeZone,
      bookingCount: (json['booking_count'] as num? ?? 0).toInt(),
      completedCount: (json['completed_count'] as num? ?? 0).toInt(),
      upcomingCount: (json['upcoming_count'] as num? ?? 0).toInt(),
      totalPaidCents: (json['total_paid_cents'] as num? ?? 0).toInt(),
      firstBookedAt: DateTime.parse(json['first_booked_at'] as String),
      lastStartsAt: DateTime.parse(json['last_starts_at'] as String),
      lastVisitLocal: wallClock('last_visit_local'),
      nextStartsAtLocal: wallClock('next_starts_at_local'),
    );
  }
}
