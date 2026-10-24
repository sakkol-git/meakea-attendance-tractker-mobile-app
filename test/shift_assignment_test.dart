import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/features/identity/application/shift_use_cases.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/core/demo/local_service.dart';

import 'support/workspace_fixture.dart';

LocalDataSource shiftsDemo({DateTime Function()? now}) => LocalDataSource(
  jsonDecode(File('assets/data/demo-seed.json').readAsStringSync()) as JsonMap,
  populate: true,
  now: now ?? () => DateTime.utc(2026, 10, 23, 3),
);
Matcher failure(int status, [String? code]) => throwsA(
  isA<DataFailure>()
      .having((e) => e.status, 'status', status)
      .having((e) => code == null || e.code == code, 'code matches', true),
);

void main() {
  test('HR assigns adjacent periods, employees see their own schedule, history and replay survive restart', () async {
    var now = DateTime.utc(2026, 10, 23, 3);
    final source = shiftsDemo(now: () => now);
    final client = ClientData.forTest(source);
    final repository = HrRepository(client);
    expect(await repository.shiftAssignments('demo-employee'), isEmpty);
    await expectLater(
      repository.shiftAssignments('demo-manager'),
      failure(403),
    );
    final hr = await client.demoLogin('HR_ADMIN');
    final key = commandKey();
    final useCases = ShiftUseCases(repository);
    final assignment = await useCases.assign(
      hr,
      'demo-employee',
      'shift-standard',
      '2026-10-26',
      '2026-10-30',
      key,
    );
    final replay = await useCases.assign(
      hr,
      'demo-employee',
      'shift-standard',
      '2026-10-26',
      '2026-10-30',
      key,
    );
    expect(replay.id, assignment.id);
    await expectLater(
      useCases.assign(
        hr,
        'demo-employee',
        'shift-standard',
        '2026-10-27',
        '2026-10-30',
        key,
      ),
      failure(409, 'IDEMPOTENCY_CONFLICT'),
    );
    await expectLater(
      useCases.assign(
        hr,
        'demo-employee',
        'shift-standard',
        '2026-10-30',
        null,
        commandKey(),
      ),
      failure(409, 'SHIFT_ASSIGNMENT_OVERLAP'),
    );
    await useCases.assign(
      hr,
      'demo-employee',
      'shift-standard',
      '2026-10-31',
      null,
      commandKey(),
    );
    final saved = source.snapshot();
    final restoredSource = shiftsDemo(now: () => now)..restore(saved);
    final restored = HrRepository(ClientData.forTest(restoredSource));
    final rows = await restored.shiftAssignments('demo-employee');
    expect(rows, hasLength(2));
    expect(rows.first.validFrom, '2026-10-31');
    expect(rows.last.includes('2026-10-30'), true);
    expect(rows.last.includes('2026-10-31'), false);
    expect((await restored.today()).shiftName, isNull);
    now = DateTime.utc(2026, 10, 27, 3);
    expect((await restored.today()).shiftName, 'Standard workday');
    restoredSource.setDemoRole('HR_ADMIN');
    final afterRestart = await restored.assignShift(
      'demo-employee',
      'shift-standard',
      '2026-10-26',
      '2026-10-30',
      key,
    );
    expect(afterRestart.id, assignment.id);
    expect(await restored.shiftAssignments('demo-employee'), hasLength(2));
  });
  test('assignment use case and demo reject unauthorized, missing and invalid inputs', () async {
    final source = shiftsDemo();
    final client = ClientData.forTest(source);
    final repository = HrRepository(client);
    final useCases = ShiftUseCases(repository);
    final employee = await client.demoLogin('EMPLOYEE');
    await expectLater(
      Future.sync(
        () => useCases.assign(
          employee,
          'demo-employee',
          'shift-standard',
          '2026-10-26',
          null,
          commandKey(),
        ),
      ),
      failure(403),
    );
    final hr = await client.demoLogin('HR_ADMIN');
    for (final dates in [
      ('2026-02-30', null),
      ('2026-11-02', '2026-11-01'),
      ('2026-10-26', '2026-13-01'),
    ]) {
      await expectLater(
        Future.sync(
          () => useCases.assign(
            hr,
            'demo-employee',
            'shift-standard',
            dates.$1,
            dates.$2,
            commandKey(),
          ),
        ),
        failure(422),
      );
      await expectLater(
        repository.assignShift(
          'demo-employee',
          'shift-standard',
          dates.$1,
          dates.$2,
          commandKey(),
        ),
        failure(422),
      );
    }
    await expectLater(
      repository.assignShift(
        'unknown',
        'shift-standard',
        '2026-10-26',
        null,
        commandKey(),
      ),
      failure(404),
    );
    await expectLater(
      repository.assignShift(
        'demo-employee',
        'unknown',
        '2026-10-26',
        null,
        commandKey(),
      ),
      failure(422),
    );
    source.setDemoRole('MANAGER');
    await expectLater(
      repository.assignShift(
        'demo-employee',
        'shift-standard',
        '2026-10-26',
        null,
        commandKey(),
      ),
      failure(403),
    );
    await expectLater(
      repository.shiftAssignments('demo-employee'),
      failure(403),
    );
  });
  test('older demo snapshots can add assignment state without losing prior records', () async {
    final source = shiftsDemo();
    final repository = HrRepository(ClientData.forTest(source));
    final record = await repository.create('request', {
      'title': 'Keep this record',
      'reason': 'Snapshot migration check',
    }, commandKey());
    final saved = source.snapshot();
    (saved['rows'] as Map).remove('/shift-assignments');
    final restored = HrRepository(
      ClientData.forTest(shiftsDemo()..restore(saved)),
    );
    expect(await restored.shiftAssignments('demo-employee'), isEmpty);
    expect(
      (await restored.detail('request', record.id)).title,
      'Keep this record',
    );
  });
}
