/// Admin views of reports and account restrictions. Shapes follow the
/// moderation RPCs (supabase/migrations/20261101140000_moderation_and_suspension.sql).
library;

import '../../shared/reports/models/report.dart';

DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse('$value');

int _int(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

String? _text(Object? value) {
  final text = value is String ? value.trim() : null;
  return text == null || text.isEmpty ? null : text;
}

/// A report in the moderation queue, with a short summary of what it's about.
class AdminReport {
  const AdminReport({
    required this.id,
    required this.target,
    required this.targetId,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.subject,
    this.details,
    this.resolution,
    this.resolvedAt,
    this.reporterId,
    this.reporterName,
    this.reportsOnTarget = 1,
  });

  factory AdminReport.fromJson(Map<String, dynamic> json) => AdminReport(
    id: json['id'] as String,
    target: ReportTarget.fromKey(json['target_type'] as String?) ?? ReportTarget.post,
    targetId: json['target_id'] as String,
    reason: ReportReason.fromKey(json['reason'] as String?),
    status: json['status'] as String? ?? 'open',
    createdAt: _date(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    details: _text(json['details']),
    resolution: _text(json['resolution']),
    resolvedAt: _date(json['resolved_at']),
    reporterId: json['reporter_id'] as String?,
    reporterName: _text(json['reporter_name']),
    reportsOnTarget: _int(json['reports_on_target']),
    subject: json['target'] is Map
        ? AdminReportSubject.fromJson(Map<String, dynamic>.from(json['target'] as Map))
        : const AdminReportSubject(),
  );

  final String id;
  final ReportTarget target;
  final String targetId;
  final ReportReason reason;

  /// `open`, `resolved` or `dismissed`.
  final String status;
  final DateTime createdAt;
  final String? details;
  final String? resolution;
  final DateTime? resolvedAt;
  final String? reporterId;
  final String? reporterName;

  /// Every report on the same thing, this one included.
  final int reportsOnTarget;
  final AdminReportSubject subject;

  bool get isOpen => status == 'open';

  /// Posts, comments and reviews can be hidden; providers and bookings can't.
  bool get canHide => target == ReportTarget.post || target == ReportTarget.comment || target == ReportTarget.review;
}

/// What a report points at, as the queue shows it. Missing once the thing
/// was deleted.
class AdminReportSubject {
  const AdminReportSubject({
    this.text,
    this.mediaUrl,
    this.authorId,
    this.authorName,
    this.hidden = false,
    this.rating,
    this.bookingStatus,
    this.paymentMethod,
    this.settlementStatus,
    this.totalCents,
    this.exists = false,
  });

  factory AdminReportSubject.fromJson(Map<String, dynamic> json) => AdminReportSubject(
    text: _text(json['text']),
    mediaUrl: _text(json['media_url']),
    authorId: json['author_id'] as String?,
    authorName: _text(json['author_name']),
    hidden: json['hidden'] == true,
    rating: json['rating'] == null ? null : _int(json['rating']),
    bookingStatus: json['status'] as String?,
    paymentMethod: json['payment_method'] as String?,
    settlementStatus: json['settlement_status'] as String?,
    totalCents: json['total_cents'] == null ? null : _int(json['total_cents']),
    exists: true,
  );

  /// The caption, comment, review text, provider name, or booking line.
  final String? text;
  final String? mediaUrl;

  /// Who's responsible: the author, or a booking's provider.
  final String? authorId;
  final String? authorName;
  final bool hidden;
  final int? rating;
  final String? bookingStatus;
  final String? paymentMethod;
  final String? settlementStatus;
  final int? totalCents;

  /// False when the reported thing has since been deleted.
  final bool exists;
}

/// An account's restrictions and report counts, for its admin page.
class AdminModerationState {
  const AdminModerationState({
    this.suspendedAt,
    this.suspendedReason,
    this.bookingsBlockedAt,
    this.bookingsBlockedReason,
    this.upcomingBookings = 0,
    this.openReportsAbout = 0,
    this.reportsMade = 0,
  });

  factory AdminModerationState.fromJson(Map<String, dynamic> json) => AdminModerationState(
    suspendedAt: _date(json['suspended_at']),
    suspendedReason: _text(json['suspended_reason']),
    bookingsBlockedAt: _date(json['bookings_blocked_at']),
    bookingsBlockedReason: _text(json['bookings_blocked_reason']),
    upcomingBookings: _int(json['upcoming_bookings']),
    openReportsAbout: _int(json['open_reports_about']),
    reportsMade: _int(json['reports_made']),
  );

  final DateTime? suspendedAt;
  final String? suspendedReason;
  final DateTime? bookingsBlockedAt;
  final String? bookingsBlockedReason;
  final int upcomingBookings;
  final int openReportsAbout;
  final int reportsMade;

  bool get isSuspended => suspendedAt != null;

  bool get bookingsBlocked => bookingsBlockedAt != null;
}
