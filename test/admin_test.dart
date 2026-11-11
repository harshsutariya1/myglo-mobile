import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/admin/controllers/admin_controllers.dart';
import 'package:myglo/src/features/admin/models/admin_failure.dart';
import 'package:myglo/src/features/admin/models/admin_models.dart';
import 'package:myglo/src/features/admin/models/admin_repository.dart';
import 'package:myglo/src/features/admin/views/admin_people_screen.dart';
import 'package:myglo/src/features/admin/views/admin_shell.dart';
import 'package:myglo/src/features/admin/views/audit_log_screen.dart';
import 'package:myglo/src/features/admin/views/platform_settings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Answers the admin calls the screens under test make; anything else fails.
class _FakeAdminRepository implements AdminRepository {
  _FakeAdminRepository({this.users = const []});

  final List<AdminUserSummary> users;
  final searches = <(String?, String?)>[];

  @override
  Future<List<AdminUserSummary>> searchUsers({String? query, String? role, int limit = 30, int offset = 0}) async {
    searches.add((query, role));
    return users
        .where((u) => role == null || u.role == role)
        .where((u) => query == null || query.isEmpty || u.title.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

AdminUserSummary _user(String id, String role, String name) => AdminUserSummary(
      userId: id,
      role: role,
      displayName: role == 'provider' ? 'Owner $name' : name,
      businessName: role == 'provider' ? name : null,
      email: '$id@example.test',
      createdAt: DateTime.utc(2026, 10, 1),
    );

Widget _app(Widget child, {List<Override> overrides = const []}) => ProviderScope(
      overrides: overrides,
      retry: (_, _) => null,
      child: MaterialApp(theme: AppTheme.lightTheme, home: child),
    );

void main() {
  group('AdminFailure', () {
    test('maps the server refusal keys', () {
      AdminFailure from(String message) => AdminFailure.from(PostgrestException(message: message, code: '42501'));

      expect(from('reauth_required').code, AdminFailureCode.reauthRequired);
      expect(from('admin_session_expired').needsVerification, isTrue);
      expect(from('mfa_required').needsVerification, isTrue);
      expect(from('reauth_required').needsVerification, isFalse);
      expect(from('admin_required').code, AdminFailureCode.adminRequired);
      expect(from('something new').code, AdminFailureCode.unknown);
      expect(from('something new').isExpected, isFalse);
    });

    test('keeps the detail of an invalid setting', () {
      final failure = AdminFailure.from(
        const PostgrestException(message: 'invalid_setting', code: '22023', details: 'owner'),
      );
      expect(failure.code, AdminFailureCode.invalidSetting);
      expect(failure.message, contains('owner'));
    });
  });

  group('PlatformSettings', () {
    test('changesTo lists only the values that changed', () {
      const saved = PlatformSettings(platformFeePercent: 0, feeFreeDays: 14);
      final edited = saved.copyWith(platformFeePercent: 5.5, checkoutHoldMinutes: 20);
      expect(saved.changesTo(edited), {'platform_fee_percent': 5.5, 'checkout_hold_minutes': 20});
      expect(saved.changesTo(saved), isEmpty);
    });

    test('reads the server JSON, including whole-number fees', () {
      final settings = PlatformSettings.fromJson({
        'platform_fee_percent': 5,
        'fee_free_days': 14,
        'map_provider': 'google',
        'updated_by': 'Harsh',
      });
      expect(settings.platformFeePercent, 5.0);
      expect(settings.feeFreeDays, 14);
      expect(settings.updatedBy, 'Harsh');
    });

    test('every editable setting has a form field with the database range', () {
      final fields = {for (final (_, group) in settingGroups) for (final f in group) f.key: f};
      final editable = const PlatformSettings().toChanges().keys.toSet()..remove('map_provider');
      final toggles = {for (final (_, group) in settingToggleGroups) for (final t in group) t.key};
      expect({...fields.keys, ...toggles}, editable);
      expect(toggles, {'provider_self_deletion'});
      expect((fields['card_max_advance_days']!.min, fields['card_max_advance_days']!.max), (1, 85));
      expect((fields['checkout_hold_minutes']!.min, fields['checkout_hold_minutes']!.max), (5, 60));
    });
  });

  test('AuditEntry lists the changed fields', () {
    final entry = AuditEntry(
      id: 1,
      action: 'platform_settings.update',
      before: const {'platform_fee_percent': 0, 'fee_free_days': 14},
      after: const {'platform_fee_percent': 5.5, 'fee_free_days': 14},
      createdAt: DateTime.utc(2026, 10, 31),
    );
    expect(entry.changedFields, [('platform_fee_percent', 0, 5.5)]);
    expect(describeAuditAction(entry.action), 'Changed platform settings');
  });

  test('the admin shell highlights the section a page belongs to', () {
    expect(AdminShell.selectedIndex('/admin'), 0);
    expect(AdminShell.selectedIndex('/admin/people/abc'), 1);
    expect(AdminShell.selectedIndex('/admin/settings/cities/edit'), 4);
  });

  group('PlatformSettingsForm', () {
    testWidgets('counts changes, validates ranges and discards', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: PlatformSettingsForm(saved: PlatformSettings(feeFreeDays: 14)))));

      expect(find.text('No changes'), findsOneWidget);

      final fee = find.widgetWithText(TextFormField, 'Myglo fee');
      await tester.enterText(fee, '5.5');
      await tester.pump();
      expect(find.text('Save 1 change'), findsOneWidget);

      await tester.enterText(fee, '140');
      await tester.pump();
      expect(find.text('Between 0 and 100'), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await tester.pump();
      expect(find.text('No changes'), findsOneWidget);
      expect(find.text('Between 0 and 100'), findsNothing);
    });

    testWidgets('provider self-deletion is an off-by-default switch that counts as a change', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: PlatformSettingsForm(saved: PlatformSettings()))));
      final toggle = find.widgetWithText(SwitchListTile, 'Providers can delete their own account');
      await tester.scrollUntilVisible(toggle, 200, scrollable: find.byType(Scrollable).first);
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);

      await tester.tap(toggle);
      await tester.pump();

      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      expect(find.text('Save 1 change'), findsOneWidget);
    });

    testWidgets("won't save a value outside the database's range", (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: PlatformSettingsForm(saved: PlatformSettings()))));
      final hold = find.widgetWithText(TextFormField, 'Checkout hold');
      await tester.scrollUntilVisible(hold, 200, scrollable: find.byType(Scrollable).first);
      await tester.enterText(hold, '3');
      await tester.pump();
      expect(find.text('Between 5 and 60'), findsOneWidget);
      expect(find.text('No changes'), findsOneWidget);
    });
  });

  testWidgets('people search filters by role', (tester) async {
    final repo = _FakeAdminRepository(users: [
      _user('p-1', 'provider', 'Glow Studio'),
      _user('c-1', 'customer', 'Mia Tran'),
    ]);
    await tester.pumpWidget(_app(
      const AdminPeopleScreen(),
      overrides: [adminRepositoryProvider.overrideWithValue(repo)],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Glow Studio'), findsOneWidget);
    expect(find.text('Mia Tran'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Providers'));
    await tester.pumpAndSettle();
    expect(find.text('Glow Studio'), findsOneWidget);
    expect(find.text('Mia Tran'), findsNothing);
    expect(repo.searches.last, ('', 'provider'));
  });

  test('user search queries compare by value', () {
    expect(const AdminUserQuery(text: 'a', role: 'provider'), const AdminUserQuery(text: 'a', role: 'provider'));
    expect(const AuditFilter(targetType: 'user', targetId: 'x'), const AuditFilter(targetType: 'user', targetId: 'x'));
  });
}
