import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/models/piva.dart';
import 'package:budgetti/models/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The three Drift-backed sources are swapped for `Stream.value`, so no database
// is opened and nothing listens on a port.

const _profile = PivaProfileData(
  atecoCode: '62.01.00',
  coefficient: 67,
  startYear: 2024,
  startupRate: true,
  fundType: 'gestione_separata',
  fundName: '',
  subjectiveRate: 0,
  integrativeRate: 0,
  minSubjective: 0,
  minIntegrative: 0,
  inpsReduction: false,
  incomeCategories: ['Fatture'],
);

ProviderContainer _container(PivaProfileData? profile) {
  final container = ProviderContainer(
    overrides: [
      pivaProfileProvider.overrideWith((ref) => Stream.value(profile)),
      pivaPaymentsProvider.overrideWith(
        (ref) => Stream.value(const <PivaPaymentData>[]),
      ),
      pivaTransactionsProvider.overrideWith(
        (ref) => Stream.value([
          Transaction(
            id: 't1',
            accountId: 'a1',
            amount: 1000,
            date: DateTime(2026, 3, 15, 12),
            description: '',
            category: 'Fatture',
            type: 'income',
          ),
        ]),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Lets the three sources deliver before the derivation is read. Riverpod 3
/// pauses a provider nobody listens to, so a bare `read` of the stream never
/// sees it emit: listen first (the screen's `watch` does the same).
Future<void> _loaded(ProviderContainer container) async {
  container.listen(pivaProfileProvider, (_, _) {});
  container.listen(pivaPaymentsProvider, (_, _) {});
  container.listen(pivaTransactionsProvider, (_, _) {});
  await container.read(pivaProfileProvider.future);
  await container.read(pivaPaymentsProvider.future);
  await container.read(pivaTransactionsProvider.future);
}

void main() {
  test('senza profilo la vista è AsyncData(null)', () async {
    final container = _container(null);
    await _loaded(container);

    final view = container.read(pivaViewProvider(2026));
    expect(view.hasValue, isTrue);
    expect(view.value, isNull);
  });

  test('con profilo la vista si deriva una volta sola per anno', () async {
    final container = _container(_profile);
    await _loaded(container);

    final first = container.read(pivaViewProvider(2026)).value;
    expect(first, isNotNull);
    expect(first!.year, 2026);
    // Same instance on the second read: a rebuild recomputes nothing.
    expect(container.read(pivaViewProvider(2026)).value, same(first));

    final other = container.read(pivaViewProvider(2025)).value;
    expect(other, isNot(same(first)));
    expect(other!.year, 2025);
  });

  test("pivaYearProvider parte dall'anno in corso e si imposta", () {
    final container = _container(null);
    expect(container.read(pivaYearProvider), DateTime.now().year);

    container.read(pivaYearProvider.notifier).set(2024);
    expect(container.read(pivaYearProvider), 2024);
  });
}
