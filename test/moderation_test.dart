import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/admin/models/admin_failure.dart';
import 'package:myglo/src/features/admin/models/admin_moderation.dart';
import 'package:myglo/src/features/admin/models/admin_repository.dart';
import 'package:myglo/src/features/admin/views/admin_moderation_screen.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_enums.dart';
import 'package:myglo/src/features/shared/reports/models/report.dart';
import 'package:myglo/src/features/shared/reports/models/report_failure.dart';
import 'package:myglo/src/features/shared/reports/models/reports_repository.dart';
import 'package:myglo/src/features/shared/reports/views/report_sheet.dart';
import 'package:myglo/src/features/shared/reviews/models/review.dart';
import 'package:myglo/src/features/shared/reviews/views/widgets/review_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/booking_fixtures.dart';

/// Records reports instead of sending them; fails with [failWith] if set.
class _FakeReports implements ReportsRepository {
  _FakeReports({this.failWith});

  final ReportFailure? failWith;
  final sent = <(ReportTarget, String, ReportReason, String?)>[];

  @override
  Future<String> submit({
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    String? details,
  }) async {
    if (failWith != null) throw failWith!;
    sent.add((target, targetId, reason, details));
    return 'report-1';
  }
}

/// Answers the moderation calls the screen makes; anything else fails.
class _FakeAdminRepository implements AdminRepository {
  _FakeAdminRepository(this.reports);

  final List<AdminReport> reports;
  final statuses = <String?>[];

  @override
  Future<List<AdminReport>> listReports({String? status = 'open', int limit = 30, int offset = 0}) async {
    statuses.add(status);
    return reports.where((r) => r.status == status).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

AppUserProfile _viewer(String id, UserRole role) => AppUserProfile(
      rawUser: User(
        id: id,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
      ),
      role: role,
      profile: ProfileModel(id: id, role: role, firstName: 'Test'),
    );

Review _review({bool hidden = false}) => Review(
      id: 'review-1',
      bookingId: 'booking-1',
      providerId: 'prov-1',
      clientId: 'client-1',
      reviewerName: 'Michelle Z.',
      rating: 2,
      body: 'Not great',
      createdAt: DateTime.utc(2026, 10, 8),
      isHidden: hidden,
    );

Widget _app(Widget child, {List<Override> overrides = const []}) => ProviderScope(
      overrides: overrides,
      retry: (_, _) => null,
      child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child)),
    );

/// A button that opens the report sheet, as the screens do.
class _Opener extends StatelessWidget {
  const _Opener({required this.target});

  final ReportTarget target;

  @override
  Widget build(BuildContext context) => Center(
        child: FilledButton(
          onPressed: () => showReportSheet(context, target: target, targetId: 'target-1'),
          child: const Text('Open'),
        ),
      );
}

void main() {
  group('Reports', () {
    test('map the server refusal keys', () {
      ReportFailure from(String message) => ReportFailure.from(PostgrestException(message: message, code: 'P0001'));

      expect(from('report_window_closed').code, ReportFailureCode.windowClosed);
      expect(from('too_many_reports').code, ReportFailureCode.tooManyReports);
      expect(from('account_suspended').code, ReportFailureCode.accountSuspended);
      expect(from('report_target_not_found').isExpected, isTrue);
      expect(from('something new').isExpected, isFalse);
    });

    test('offer reasons that fit what is reported', () {
      expect(ReportTarget.booking.reasons, contains(ReportReason.noShow));
      expect(ReportTarget.comment.reasons, isNot(contains(ReportReason.noShow)));
      expect(ReportReason.fake.labelFor(ReportTarget.review), 'Fake review or not a real booking');
      expect(ReportReason.fake.labelFor(ReportTarget.provider), 'Fake or misleading profile');
      for (final target in ReportTarget.values) {
        expect(target.reasons.last, ReportReason.other, reason: target.key);
        expect(ReportTarget.fromKey(target.key), target);
      }
    });

    testWidgets('need a reason (and words for "Something else") before sending', (tester) async {
      final reports = _FakeReports();
      await tester.pumpWidget(_app(
        const _Opener(target: ReportTarget.post),
        overrides: [reportsRepositoryProvider.overrideWithValue(reports)],
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      FilledButton send() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Send report'));
      expect(find.text('Report post'), findsOneWidget);
      expect(send().onPressed, isNull);

      await tester.tap(find.text('Something else'));
      await tester.pump();
      expect(send().onPressed, isNull);
      await tester.enterText(find.byType(TextField), '  Uses my photos  ');
      await tester.pump();
      expect(send().onPressed, isNotNull);

      await tester.tap(find.text('Spam'));
      await tester.pump();
      await tester.ensureVisible(find.text('Send report'));
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();

      expect(reports.sent.single, (ReportTarget.post, 'target-1', ReportReason.spam, '  Uses my photos  '));
      expect(find.text('Report post'), findsNothing);
      expect(find.textContaining("Myglo's team will look into it"), findsOneWidget);
    });

    testWidgets('show why a report was refused and stay open', (tester) async {
      await tester.pumpWidget(_app(
        const _Opener(target: ReportTarget.booking),
        overrides: [
          reportsRepositoryProvider.overrideWithValue(
            _FakeReports(failWith: const ReportFailure(ReportFailureCode.windowClosed)),
          ),
        ],
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Report a problem'), findsOneWidget);
      await tester.tap(find.text("The provider didn't turn up"));
      await tester.pump();
      await tester.ensureVisible(find.text('Send report'));
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();

      expect(find.text(const ReportFailure(ReportFailureCode.windowClosed).message), findsOneWidget);
      expect(find.text('Report a problem'), findsOneWidget);
    });
  });

  group('Reviews', () {
    test('read whether Myglo hid them', () {
      final json = {
        'id': 'review-1',
        'booking_id': 'booking-1',
        'provider_id': 'prov-1',
        'client_id': 'client-1',
        'rating': 4,
        'created_at': '2026-10-08T00:00:00Z',
      };
      expect(Review.fromJson(json).isHidden, isFalse);
      expect(Review.fromJson({...json, 'is_hidden': true}).isHidden, isTrue);
    });

    testWidgets('can be reported by others, such as the reviewed provider', (tester) async {
      await tester.pumpWidget(_app(
        ReviewCard(review: _review()),
        overrides: [userProfileProvider.overrideWith((ref) async => _viewer('prov-1', UserRole.provider))],
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Report review'), findsOneWidget);
    });

    testWidgets("can't be reported by their author", (tester) async {
      await tester.pumpWidget(_app(
        ReviewCard(review: _review()),
        overrides: [userProfileProvider.overrideWith((ref) async => _viewer('client-1', UserRole.customer))],
      ));
      await tester.pumpAndSettle();
      expect(find.byTooltip('More'), findsNothing);
    });

    testWidgets('tell their author when Myglo hid them', (tester) async {
      await tester.pumpWidget(_app(
        ReviewCard(review: _review(hidden: true)),
        overrides: [userProfileProvider.overrideWith((ref) async => _viewer('client-1', UserRole.customer))],
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hidden by Myglo'), findsOneWidget);
    });
  });

  test('a booking problem can be reported from the start until the window after the end', () {
    final start = DateTime.utc(2026, 11, 1, 0);
    final booking = sampleBooking(startsAt: start); // Ends 90 minutes later.
    final end = start.add(const Duration(minutes: 90));
    bool canReport(DateTime now, {BookingStatus status = BookingStatus.confirmed}) =>
        booking.copyWith(status: status).canReportProblem(now, windowHours: 24);

    expect(canReport(start.subtract(const Duration(minutes: 1))), isFalse);
    expect(canReport(start), isTrue);
    expect(canReport(end.add(const Duration(hours: 24))), isTrue);
    expect(canReport(end.add(const Duration(hours: 24, minutes: 1))), isFalse);
    expect(canReport(start, status: BookingStatus.completed), isTrue);
    expect(canReport(start, status: BookingStatus.noShow), isTrue);
    expect(canReport(start, status: BookingStatus.cancelled), isFalse);
  });

  group('Admin moderation', () {
    final report = AdminReport.fromJson({
      'id': 'report-1',
      'target_type': 'post',
      'target_id': 'post-1',
      'reason': 'harassment',
      'details': 'Rude caption',
      'status': 'open',
      'created_at': '2026-11-01T01:00:00Z',
      'reporter_id': 'client-1',
      'reporter_name': 'Michelle Zhang',
      'reports_on_target': 3,
      'target': {'text': 'A rude caption', 'author_id': 'prov-1', 'author_name': 'Glow Studio', 'hidden': false},
    });

    test('reads a report and what it points at', () {
      expect(report.target, ReportTarget.post);
      expect(report.reason, ReportReason.harassment);
      expect(report.reason.isUrgent, isTrue);
      expect(report.canHide, isTrue);
      expect(report.subject.authorName, 'Glow Studio');
      expect(report.subject.exists, isTrue);

      final deleted = AdminReport.fromJson({
        'id': 'report-2',
        'target_type': 'booking',
        'target_id': 'b-1',
        'reason': 'no_show',
        'status': 'open',
        'created_at': '2026-11-01T01:00:00Z',
        'target': null,
      });
      expect(deleted.canHide, isFalse);
      expect(deleted.subject.exists, isFalse);
    });

    test('reads an account\'s restrictions', () {
      final state = AdminModerationState.fromJson({
        'suspended_at': '2026-11-01T01:00:00Z',
        'suspended_reason': 'Abuse',
        'bookings_blocked_at': null,
        'upcoming_bookings': 2,
        'open_reports_about': 1,
        'reports_made': 0,
      });
      expect(state.isSuspended, isTrue);
      expect(state.bookingsBlocked, isFalse);
      expect(state.upcomingBookings, 2);
      expect(
        AdminFailure.from(const PostgrestException(message: 'report_closed', code: 'P0001')).code,
        AdminFailureCode.reportClosed,
      );
    });

    testWidgets('lists open reports and opens one with its actions', (tester) async {
      final repository = _FakeAdminRepository([report]);
      await tester.pumpWidget(ProviderScope(
        overrides: [adminRepositoryProvider.overrideWithValue(repository)],
        retry: (_, _) => null,
        child: MaterialApp(theme: AppTheme.lightTheme, home: const AdminModerationScreen()),
      ));
      await tester.pumpAndSettle();

      expect(repository.statuses, ['open']);
      expect(find.text('Post · Harassment'), findsOneWidget);
      expect(find.text('3 reports'), findsOneWidget);

      await tester.tap(find.text('Post · Harassment'));
      await tester.pumpAndSettle();
      expect(find.text('"Rude caption"'), findsOneWidget);
      expect(find.text('Hide post'), findsOneWidget);
      expect(find.text('Resolve'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resolved'));
      await tester.pumpAndSettle();
      expect(repository.statuses, ['open', 'resolved']);
      expect(find.text('No reports here yet.'), findsOneWidget);
    });
  });
}
