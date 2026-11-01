/// What a report is about. The keys match `reports.target_type`.
enum ReportTarget {
  post('post', 'post'),
  comment('comment', 'comment'),
  review('review', 'review'),
  provider('provider', 'provider'),
  booking('booking', 'booking');

  const ReportTarget(this.key, this.noun);

  final String key;

  /// "post", "comment"… for titles like "Report post".
  final String noun;

  static ReportTarget? fromKey(String? key) {
    for (final target in values) {
      if (target.key == key) return target;
    }
    return null;
  }

  /// The reasons offered for this kind of report, most likely first.
  List<ReportReason> get reasons => switch (this) {
    post => const [
      ReportReason.inappropriate,
      ReportReason.spam,
      ReportReason.harassment,
      ReportReason.fake,
      ReportReason.scam,
      ReportReason.other,
    ],
    comment => const [ReportReason.harassment, ReportReason.spam, ReportReason.inappropriate, ReportReason.other],
    review => const [
      ReportReason.fake,
      ReportReason.inappropriate,
      ReportReason.harassment,
      ReportReason.spam,
      ReportReason.other,
    ],
    provider => const [
      ReportReason.scam,
      ReportReason.fake,
      ReportReason.safety,
      ReportReason.harassment,
      ReportReason.inappropriate,
      ReportReason.other,
    ],
    booking => const [
      ReportReason.noShow,
      ReportReason.serviceNotAsDescribed,
      ReportReason.overcharged,
      ReportReason.safety,
      ReportReason.harassment,
      ReportReason.other,
    ],
  };
}

/// Why something was reported. The keys match `reports.reason`.
enum ReportReason {
  spam('spam'),
  inappropriate('inappropriate'),
  harassment('harassment'),
  scam('scam'),
  fake('fake'),
  safety('safety'),
  noShow('no_show'),
  serviceNotAsDescribed('service_not_as_described'),
  overcharged('overcharged'),
  other('other');

  const ReportReason(this.key);

  final String key;

  static ReportReason fromKey(String? key) {
    for (final reason in values) {
      if (reason.key == key) return reason;
    }
    return other;
  }

  /// How the reporter sees the reason, in the words that fit [target].
  String labelFor(ReportTarget target) => switch (this) {
    spam => 'Spam',
    inappropriate => 'Nudity or inappropriate content',
    harassment => 'Harassment or hate',
    scam => 'Scam or fraud',
    fake => switch (target) {
      ReportTarget.review => "Fake review or not a real booking",
      ReportTarget.provider => 'Fake or misleading profile',
      _ => 'Misleading or stolen photos',
    },
    safety => target == ReportTarget.booking ? 'I felt unsafe' : 'Safety concern',
    noShow => "The provider didn't turn up",
    serviceNotAsDescribed => "The service wasn't what I booked",
    overcharged => 'I was asked to pay more than I booked',
    other => 'Something else',
  };

  /// A short label for the admin queue.
  String get adminLabel => switch (this) {
    spam => 'Spam',
    inappropriate => 'Inappropriate',
    harassment => 'Harassment',
    scam => 'Scam',
    fake => 'Fake or misleading',
    safety => 'Safety',
    noShow => 'No-show',
    serviceNotAsDescribed => 'Not as booked',
    overcharged => 'Overcharged',
    other => 'Other',
  };

  /// Urgent reasons the admin queue highlights.
  bool get isUrgent => this == safety || this == harassment;
}
