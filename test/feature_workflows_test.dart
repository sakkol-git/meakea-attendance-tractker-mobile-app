import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/app/feature_panels.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/demo/local_service.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/features/operations/data/repository.dart';

import 'support/workspace_fixture.dart';

LocalDataSource demo() => LocalDataSource(
  jsonDecode(File('assets/data/demo-seed.json').readAsStringSync()) as JsonMap,
  populate: true,
  now: () => DateTime.utc(2026, 10, 23, 3),
);
Matcher failure(int status) =>
    throwsA(isA<DataFailure>().having((e) => e.status, 'status', status));
void main() {
  test(
    'every feature view has a readable owned adapter and correct role boundary',
    () async {
      final source = demo();
      final repository = HrRepository(ClientData.forTest(source));
      source.setDemoRole('OWNER');
      for (final panel in featurePanels.where(
        (p) => !p.key.startsWith('operations.'),
      )) {
        final rows = await repository.cases(panel.key);
        expect(
          rows.every((r) => r.id.isNotEmpty && r.title.isNotEmpty),
          true,
          reason: panel.key,
        );
      }
      final operational = OperationsDataRepository(ClientData.forTest(source));
      expect(await operational.cases('operations.readiness'), hasLength(8));
      source.setDemoRole('EMPLOYEE');
      await expectLater(repository.cases('leave.balances'), failure(403));
      await expectLater(
        operational.cases('operations.readiness'),
        failure(403),
      );
    },
  );
  test('manual attendance retains raw history, opens leave conflict and blocks finalization until independent resolution', () async {
    final source = demo();
    final repo = HrRepository(ClientData.forTest(source));
    source.setDemoRole('HR_ADMIN');
    final before = (source.snapshot()['sessions'] as List).length;
    await repo.changeCase('attendance.manual', null, {
      'employeeId': 'demo-employee',
      'workDate': '2026-10-19',
      'checkIn': '08:30',
      'checkOut': '17:30',
      'reason': 'Verified work with employee',
    }, key: commandKey());
    expect((source.snapshot()['sessions'] as List).length, before + 1);
    expect(
      (source.snapshot()['sessions'] as List).any(
        (s) => s['supersededBy'] != null,
      ),
      true,
    );
    var conflicts = await repo.cases('leave.conflicts');
    expect(conflicts, hasLength(1));
    final days = await repo.cases(
      'attendance.team-days',
      filters: {'from': '2026-10-19', 'to': '2026-10-19'},
    );
    final day = days.firstWhere(
      (v) => v.values['employeeId'] == 'demo-employee',
    );
    expect(day.values['workedMinutes'], 540);
    await expectLater(
      repo.changeCase(
        'attendance.finalize',
        day.id,
        {'reason': 'Reviewed all evidence'},
        key: commandKey(),
        etag: day.etag,
      ),
      failure(409),
    );
    final conflict = conflicts.single;
    await repo.changeCase(
      'leave.conflict.resolve',
      conflict.values['leaveRequestId'],
      {
        'conflictId': conflict.id,
        'action': 'CANCEL_LEAVE',
        'reason': 'Employee worked this entire day',
      },
      key: commandKey(),
      etag: conflict.etag,
    );
    expect((await repo.cases('leave.conflicts')).single.status, 'RESOLVED');
    final updated = (await repo.cases(
      'attendance.team-days',
      filters: {'from': '2026-10-19', 'to': '2026-10-19'},
    )).firstWhere((v) => v.id == day.id);
    await expectLater(
      repo.changeCase(
        'attendance.finalize',
        day.id,
        {'reason': 'Reviewed all evidence'},
        key: commandKey(),
        etag: day.etag,
      ),
      failure(412),
    );
    await repo.changeCase(
      'attendance.finalize',
      updated.id,
      {'reason': 'Reviewed all evidence'},
      key: commandKey(),
      etag: updated.etag,
    );
    expect(
      (await repo.cases(
        'attendance.team-days',
        filters: {'from': '2026-10-19', 'to': '2026-10-19'},
      )).firstWhere((v) => v.id == day.id).values['finalized'],
      true,
    );
  });
  test('exact half-day and cross-year reservations, adjustment revisions and stale rollover preview', () async {
    final source = demo();
    final r = HrRepository(ClientData.forTest(source));
    final leave = await r.create('leave', {
      'leaveTypeId': 'annual',
      'startDate': '2026-12-31',
      'endDate': '2027-01-04',
      'portion': 'FULL_DAY',
      'reason': 'Family travel across year',
    }, commandKey());
    expect(
      (leave.fields['dayPortions'] as List).map((p) => p['date']),
      containsAll(['2026-12-31', '2027-01-01', '2027-01-04']),
    );
    source.setDemoRole('HR_ADMIN');
    final annual = (await r.cases('leave.balances')).firstWhere(
      (b) =>
          b.values['employeeId'] == 'demo-employee' &&
          b.values['leaveTypeId'] == 'annual',
    );
    expect(annual.values['pending'], 1);
    await expectLater(
      r.changeCase('leave.rollover.preview', null, {
        'fromYear': 2026,
        'carryLimit': 5,
        'reason': 'Approved company carry policy',
      }, key: commandKey()),
      failure(409),
    );
    source.setDemoRole('EMPLOYEE');
    await r.decide(leave, 'cancel', 'Travel cancelled', commandKey());
    final half = await r.create('leave', {
      'leaveTypeId': 'annual',
      'startDate': '2026-10-26',
      'endDate': '2026-10-26',
      'portion': 'MORNING',
      'reason': 'Morning appointment',
    }, commandKey());
    expect(half.fields['days'], 0.5);
    source.setDemoRole('HR_ADMIN');
    final preview = await r.changeCase('leave.rollover.preview', null, {
      'fromYear': 2026,
      'carryLimit': 5,
      'reason': 'Approved company carry policy',
    }, key: commandKey());
    final balance = (await r.cases('leave.balances')).firstWhere(
      (b) =>
          b.values['employeeId'] == 'demo-employee' &&
          b.values['leaveTypeId'] == 'annual',
    );
    final input = {
      'leaveTypeId': 'annual',
      'year': 2026,
      'delta': 0.25,
      'reason': 'Approved entitlement correction',
    };
    final key = commandKey();
    await r.changeCase(
      'leave.adjust',
      'demo-employee',
      input,
      key: key,
      etag: balance.etag,
    );
    await r.changeCase(
      'leave.adjust',
      'demo-employee',
      input,
      key: key,
      etag: balance.etag,
    );
    await expectLater(
      r.changeCase(
        'leave.adjust',
        'demo-employee',
        input,
        key: commandKey(),
        etag: balance.etag,
      ),
      failure(412),
    );
    await expectLater(
      r.changeCase('leave.rollover.apply', null, {
        'fromYear': 2026,
        'carryLimit': 5,
        'reason': 'Approved company carry policy',
        'previewId': preview['previewId'],
      }, key: commandKey()),
      failure(409),
    );
    final fresh = await r.changeCase('leave.rollover.preview', null, {
      'fromYear': 2026,
      'carryLimit': 5,
      'reason': 'Approved company carry policy',
    }, key: commandKey());
    final applyKey = commandKey(),
        body = {
          'fromYear': 2026,
          'carryLimit': 5,
          'reason': 'Approved company carry policy',
          'previewId': fresh['previewId'],
        };
    await r.changeCase('leave.rollover.apply', null, body, key: applyKey);
    await r.changeCase('leave.rollover.apply', null, body, key: applyKey);
    expect(await r.cases('leave.rollovers'), hasLength(1));
  });
  test('material chain freezes at submit and partial issues enforce stock, remaining quantity and replay', () async {
    final source = demo();
    final repo = HrRepository(ClientData.forTest(source));
    var request = await repo.create('request', {
      'title': 'Design equipment',
      'type': 'MATERIAL',
      'items': [
        {'materialId': 'monitor', 'quantity': 3},
      ],
      'quantity': 3,
      'reason': 'Additional design equipment',
    }, commandKey());
    request = await repo.decide(
      request,
      'submit',
      'Ready for review',
      commandKey(),
    );
    source.setDemoRole('HR_ADMIN');
    await expectLater(
      repo.decide(request, 'approve', 'Reviewed', commandKey()),
      failure(403),
    );
    source.setDemoRole('MANAGER');
    request = await repo.decide(
      request,
      'approve',
      'Approved team equipment',
      commandKey(),
    );
    expect(request.status, 'PENDING');
    source.setDemoRole('HR_ADMIN');
    request = await repo.decide(
      request,
      'approve',
      'Approved budget',
      commandKey(),
    );
    var line = (await repo.cases('requests.fulfillment')).single;
    final issueKey = commandKey(),
        body = {
          'materialId': 'monitor',
          'quantity': 2,
          'note': 'Collected by employee',
        };
    await repo.changeCase(
      'requests.issue',
      request.id,
      body,
      key: issueKey,
      etag: line.etag,
    );
    await repo.changeCase(
      'requests.issue',
      request.id,
      body,
      key: issueKey,
      etag: line.etag,
    );
    line = (await repo.cases('requests.fulfillment')).single;
    expect(line.values['remainingQuantity'], 1);
    await expectLater(
      repo.changeCase(
        'requests.issue',
        request.id,
        body,
        key: commandKey(),
        etag: line.etag,
      ),
      failure(409),
    );
    await repo.changeCase(
      'requests.issue',
      request.id,
      {'materialId': 'monitor', 'quantity': 1, 'note': 'Final collection'},
      key: commandKey(),
      etag: line.etag,
    );
    expect(await repo.cases('requests.fulfillment'), isEmpty);
    expect(await repo.cases('requests.issues'), hasLength(2));
    expect(
      (await repo.cases('requests.inventory'))
          .firstWhere((v) => v.id == 'monitor')
          .values['stock'],
      7,
    );
  });
  test(
    'private attachments cannot be fetched through another owned record',
    () async {
      final source = demo();
      final r = HrRepository(ClientData.forTest(source));
      final first = await r.create('request', {
            'title': 'First request',
            'reason': 'Support requested',
          }, commandKey()),
          second = await r.create('request', {
            'title': 'Second request',
            'reason': 'Support requested',
          }, commandKey());
      await r.attach(first, 'support.pdf', Uint8List.fromList([1, 2, 3]));
      final updated = await r.detail('request', first.id),
          file =
              (await r.detail('request', first.id)).fields['attachments'][0]
                  as JsonMap;
      expect(await r.download(updated, file), [1, 2, 3]);
      await expectLater(r.download(second, file), failure(404));
    },
  );
  test('shift policy snapshots preserve history and closed effective periods allow replacement', () async {
    final source = demo();
    final r = HrRepository(ClientData.forTest(source));
    source.setDemoRole('HR_ADMIN');
    final assignment = await r.assignShift(
      'demo-employee',
      'shift-standard',
      '2026-10-01',
      null,
      commandKey(),
    );
    final shift = (await r.cases('identity.shifts')).single;
    await r.changeCase(
      'identity.shift.edit',
      shift.id,
      {
        'name': 'Later workday',
        'startTime': '10:00',
        'endTime': '19:00',
        'workingDays': 31,
        'graceMinutes': 10,
        'earlyToleranceMinutes': 0,
        'reason': 'New scheduling policy',
      },
      key: commandKey(),
      etag: shift.etag,
    );
    source.setDemoRole('EMPLOYEE');
    expect((await r.get('/attendance/today'))['shift']['startTime'], '08:30');
    source.setDemoRole('HR_ADMIN');
    await r.changeCase(
      'identity.assignment.close',
      assignment.id,
      {'validTo': '2026-10-23', 'reason': 'New policy begins next week'},
      key: commandKey(),
      etag: '"1"',
    );
    await r.assignShift(
      'demo-employee',
      'shift-standard',
      '2026-10-24',
      null,
      commandKey(),
    );
    expect(await r.cases('identity.assignments'), hasLength(2));
  });
  test(
    'exports are scoped to requester and preserve chosen report type',
    () async {
      final source = demo();
      final repo = HrRepository(ClientData.forTest(source));
      source.setDemoRole('MANAGER');
      final job = await repo.changeCase('reporting.export.create', null, {
        'report': 'LEAVE',
        'format': 'CSV',
        'from': '2026-10-01',
        'to': '2026-10-31',
      }, key: commandKey());
      final file = await repo.downloadExport(job['id']);
      expect(file.name, 'leave.csv');
      expect(utf8.decode(file.bytes), contains('approvedDays'));
      source.setDemoRole('OWNER');
      await expectLater(repo.downloadExport(job['id']), failure(404));
    },
  );
}
