import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/providers/provider_profiles/controllers/provider_services_controller.dart';
import 'package:myglo/src/features/providers/provider_profiles/models/service_model.dart';
import 'package:myglo/src/features/providers/provider_profiles/views/widgets/service_owner_menu.dart';
import 'package:myglo/src/features/shared/services/views/widgets/service_tile.dart';

class _FakeServiceActions implements ServiceActions {
  _FakeServiceActions({required this.succeed});

  final bool succeed;
  final deleted = <String>[];

  @override
  Future<bool> delete(ServiceModel service) async {
    deleted.add(service.id);
    return succeed;
  }
}

final _service = ServiceModel(
  id: 'svc-1',
  providerId: 'prov-1',
  name: 'Hair Spa',
  description: '',
  price: 89,
  durationMinutes: 45,
  createdAt: DateTime.utc(2026, 9, 1),
  category: 'Hair',
);

Future<void> _pump(WidgetTester tester, _FakeServiceActions actions) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [serviceActionsProvider.overrideWithValue(actions)],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ServiceTile(service: _service, trailing: ServiceOwnerMenu(service: _service)),
        ),
      ),
    ),
  );
}

Future<void> _openDeleteSheet(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Options for Hair Spa'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete service'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tile shows category, title, duration and AUD price', (tester) async {
    await _pump(tester, _FakeServiceActions(succeed: true));

    expect(find.text('HAIR'), findsOneWidget);
    expect(find.text('Hair Spa'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
    expect(find.text(r'$89'), findsOneWidget);
  });

  testWidgets('owner menu lists every action', (tester) async {
    await _pump(tester, _FakeServiceActions(succeed: true));

    await tester.tap(find.byTooltip('Options for Hair Spa'));
    await tester.pumpAndSettle();

    expect(find.text('Edit details'), findsOneWidget);
    expect(find.text('Duplicate as new'), findsOneWidget);
    expect(find.text('Pause service'), findsOneWidget);
    expect(find.text('Delete service'), findsOneWidget);
  });

  testWidgets('delete asks for confirmation and cancelling keeps the service', (tester) async {
    final actions = _FakeServiceActions(succeed: true);
    await _pump(tester, actions);
    await _openDeleteSheet(tester);

    expect(find.text('Delete Hair Spa?'), findsOneWidget);
    expect(find.textContaining('remove the service from your public profile'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Hair Spa?'), findsNothing);
    expect(actions.deleted, isEmpty);
  });

  testWidgets('confirming deletes the service and closes the sheet', (tester) async {
    final actions = _FakeServiceActions(succeed: true);
    await _pump(tester, actions);
    await _openDeleteSheet(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(actions.deleted, ['svc-1']);
    expect(find.text('Delete Hair Spa?'), findsNothing);
    expect(find.text('"Hair Spa" deleted'), findsOneWidget);
  });

  testWidgets('a failed delete keeps the sheet open with an error', (tester) async {
    final actions = _FakeServiceActions(succeed: false);
    await _pump(tester, actions);
    await _openDeleteSheet(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Hair Spa?'), findsOneWidget);
    expect(find.textContaining("Couldn't delete the service"), findsOneWidget);
  });
}
