import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/features/customers/booking/controllers/service_selection_controller.dart';
import 'package:myglo/src/features/customers/booking/models/service_selection.dart';
import 'package:myglo/src/features/providers/provider_profiles/controllers/provider_services_controller.dart';
import 'package:myglo/src/features/providers/provider_profiles/models/service_model.dart';

ServiceModel _service(String id, {double price = 45, int minutes = 60}) => ServiceModel(
  id: id,
  providerId: 'prov-1',
  name: id,
  description: '',
  price: price,
  durationMinutes: minutes,
  createdAt: DateTime.utc(2026, 9, 1),
);

void main() {
  group('ServiceSelection.resolve', () {
    test('keeps selection order and sums price and duration', () {
      final selection = ServiceSelection.resolve(
        available: [_service('a', price: 85, minutes: 90), _service('b', price: 45, minutes: 30)],
        selectedIds: ['b', 'a'],
      );

      expect(selection.services.map((s) => s.id), ['b', 'a']);
      expect(selection.totalCents, 13000);
      expect(selection.total, 130);
      expect(selection.totalMinutes, 120);
      expect(selection.countLabel, '2 services');
    });

    test('sums cents exactly', () {
      final selection = ServiceSelection.resolve(
        available: [_service('a', price: 0.1), _service('b', price: 0.2), _service('c', price: 45.15)],
        selectedIds: ['a', 'b', 'c'],
      );
      expect(selection.totalCents, 4545);
    });

    test('drops ids that no longer match a service', () {
      final selection = ServiceSelection.resolve(
        available: [_service('a')],
        selectedIds: ['gone', 'a'],
      );
      expect(selection.services.map((s) => s.id), ['a']);
      expect(selection.countLabel, '1 service');
    });

    test('is empty with nothing selected', () {
      final selection = ServiceSelection.resolve(available: [_service('a')], selectedIds: const []);
      expect(selection.isEmpty, isTrue);
      expect(selection.totalCents, 0);
      expect(selection.totalMinutes, 0);
    });
  });

  group('ServiceSelectionController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          providerServicesProvider('prov-1').overrideWith((ref) => [_service('a'), _service('b', price: 30)]),
        ],
      );
      addTearDown(container.dispose);
    });

    test('toggles, removes and clears', () {
      final ids = selectedServiceIdsProvider('prov-1');
      container.listen(ids, (_, _) {});
      final controller = container.read(ids.notifier);

      controller.toggle('a');
      controller.toggle('b');
      expect(container.read(ids), ['a', 'b']);

      controller.toggle('a');
      expect(container.read(ids), ['b']);

      controller.remove('missing');
      controller.remove('b');
      expect(container.read(ids), isEmpty);

      controller
        ..toggle('a')
        ..clear();
      expect(container.read(ids), isEmpty);
    });

    test('resolves the selection once services load', () async {
      final summary = serviceSelectionProvider('prov-1');
      container.listen(summary, (_, _) {});
      expect(container.read(summary).isEmpty, isTrue);

      await container.read(providerServicesProvider('prov-1').future);
      container.read(selectedServiceIdsProvider('prov-1').notifier)
        ..toggle('a')
        ..toggle('b');

      expect(container.read(summary).totalCents, 7500);
    });

    test('is scoped to each provider', () {
      container.listen(selectedServiceIdsProvider('prov-1'), (_, _) {});
      container.listen(selectedServiceIdsProvider('prov-2'), (_, _) {});
      container.read(selectedServiceIdsProvider('prov-1').notifier).toggle('a');

      expect(container.read(selectedServiceIdsProvider('prov-2')), isEmpty);
    });
  });
}
