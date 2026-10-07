import 'dart:ffi';

import 'package:budgetti/core/database/database.dart';
import 'package:budgetti/core/services/finance_service.dart';
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart' as sqlite3open;

// See finance_service_seed_test.dart for why the FFI loader is overridden.
void _ensureSqlite() {
  try {
    sqlite3open.open.overrideFor(
      sqlite3open.OperatingSystem.linux,
      () => DynamicLibrary.open('/lib/x86_64-linux-gnu/libsqlite3.so.0'),
    );
  } catch (_) {
    // Already overridden or not on Linux — ignore.
  }
}

/// The two writes the phone has on `piva_payments`: a whole-row save and a soft
/// delete. The reads are `finance_service_piva_test.dart`'s; here only the write.
void main() {
  setUpAll(_ensureSqlite);

  late AppDatabase db;
  late FinanceService service;
  // Drift stores dates in whole seconds: the start of the test is cut the same way.
  late DateTime start;

  Future<void> save({
    String? id,
    DateTime? dueDate,
    double amount = 100,
    DateTime? paidDate,
    String label = 'Saldo',
    String note = '',
  }) => service.savePivaPayment(
        id: id,
        key: '2026:imposta_saldo',
        kind: 'imposta',
        label: label,
        dueDate: dueDate,
        amount: amount,
        paidDate: paidDate,
        note: note,
      );

  Future<List<PivaPayment>> rows() => db.select(db.pivaPayments).get();

  setUp(() {
    db = AppDatabase.forExecutor(NativeDatabase.memory());
    service = FinanceService(db, 'user-a');
    start = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch ~/ 1000 * 1000);
  });
  tearDown(() => db.close());

  test('a row saved without an id gets one, the service user and a stamp',
      () async {
    await service.savePivaPayment(
      key: '',
      kind: 'contributi',
      label: '  Inps  ',
      dueDate: DateTime(2026, 6, 30),
      amount: 123.45,
      note: '  from the accountant ',
    );

    final r = (await rows()).single;
    expect(r.id, isNotEmpty);
    expect(r.userId, 'user-a');
    expect(r.isDeleted, isFalse);
    expect(r.lastUpdated, isNotNull);
    expect(r.lastUpdated!.isBefore(start), isFalse);
    expect(r.key, '');
    expect(r.kind, 'contributi');
    expect(r.label, 'Inps');
    expect(r.amount, 123.45);
    expect(r.note, 'from the accountant');
  });

  test('both days are saved at 12:00 local of the same day', () async {
    // The late and the early edge of a day: a UTC cut would move either.
    await save(
      dueDate: DateTime(2026, 6, 30, 23, 30),
      paidDate: DateTime(2026, 7, 1, 0, 10),
    );

    final r = (await rows()).single;
    expect(r.dueDate, DateTime(2026, 6, 30, 12));
    expect(r.paidDate, DateTime(2026, 7, 1, 12));
  });

  test('saving again with the same id leaves one row, the new values',
      () async {
    await save(dueDate: DateTime(2026, 6, 30), amount: 100);
    final first = (await rows()).single;

    await save(id: first.id, dueDate: DateTime(2026, 7, 31), amount: 250);

    final r = (await rows()).single;
    expect(r.id, first.id);
    expect(r.dueDate, DateTime(2026, 7, 31, 12));
    expect(r.amount, 250);
  });

  test('a null paidDate takes the payment away and keeps the row', () async {
    await save(dueDate: DateTime(2026, 6, 30), paidDate: DateTime(2026, 6, 28));
    final first = (await rows()).single;
    expect(first.paidDate, DateTime(2026, 6, 28, 12));

    await save(id: first.id, dueDate: DateTime(2026, 6, 30));

    final r = (await rows()).single;
    expect(r.paidDate, isNull);
    expect(r.isDeleted, isFalse);
  });

  test('an amount of 0 is saved as 0', () async {
    await save(dueDate: DateTime(2026, 6, 30), amount: 0);

    expect((await rows()).single.amount, 0);
  });

  test('a null dueDate is saved as null', () async {
    await save(dueDate: null, paidDate: DateTime(2026, 6, 28));

    final r = (await rows()).single;
    expect(r.dueDate, isNull);
    expect(r.paidDate, DateTime(2026, 6, 28, 12));
  });

  test('delete keeps the row, flags it and restamps it; watch drops it',
      () async {
    await save(dueDate: DateTime(2026, 6, 30));
    final before = (await rows()).single;
    expect(await service.watchPivaPayments().first, hasLength(1));

    await service.deletePivaPayment(before.id);

    final r = (await rows()).single;
    expect(r.isDeleted, isTrue);
    expect(r.lastUpdated!.isBefore(before.lastUpdated!), isFalse);
    expect(r.amount, before.amount);
    expect(await service.watchPivaPayments().first, isEmpty);
  });
}
