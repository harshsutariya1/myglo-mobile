/// A block of time the provider can't take bookings (holiday, errand,
/// appointment booked outside Myglo). Private to the provider.
class TimeOffBlock {
  const TimeOffBlock({required this.id, required this.startsAt, required this.endsAt, this.reason});

  final String id;

  /// Instants (UTC).
  final DateTime startsAt;
  final DateTime endsAt;
  final String? reason;

  factory TimeOffBlock.fromJson(Map<String, dynamic> json) => TimeOffBlock(
        id: json['id'] as String,
        startsAt: DateTime.parse(json['starts_at'] as String).toUtc(),
        endsAt: DateTime.parse(json['ends_at'] as String).toUtc(),
        reason: json['reason'] as String?,
      );

  /// Whether this block covers [instant].
  bool covers(DateTime instant) => !instant.isBefore(startsAt) && instant.isBefore(endsAt);

  /// Whether it overlaps the range [start, end).
  bool overlaps(DateTime start, DateTime end) => startsAt.isBefore(end) && start.isBefore(endsAt);
}
