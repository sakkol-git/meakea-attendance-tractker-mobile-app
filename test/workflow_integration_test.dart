import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/demo/local_service.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';

import 'support/workspace_fixture.dart';

import 'package:hrflow_mobile/core/data/storage.dart';

LocalDataSource demo() => LocalDataSource(
  jsonDecode(File('assets/data/demo-seed.json').readAsStringSync()) as JsonMap,
  populate: true,
  now: () => DateTime.utc(2026, 10, 23, 3),
);
void main() {
  test('demo history uses company dates around UTC midnight and newest-first ordering', () async {
    final source = LocalDataSource(
      jsonDecode(File('assets/data/demo-seed.json').readAsStringSync())
          as JsonMap,
      populate: true,
      now: () => DateTime.utc(2026, 10, 23, 18),
    );
    final sessions = await HrRepository(ClientData.forTest(source)).sessions();
    expect(
      sessions.first.clockIn.toUtc().add(const Duration(hours: 7)).day,
      23,
    );
    for (var i = 1; i < sessions.length; i++) {
      expect(sessions[i - 1].clockIn.isAfter(sessions[i].clockIn), true);
    }
  });
  test(
    'employee reviews an inferred session with version and replay guards',
    () async {
      final repository = HrRepository(ClientData.forTest(demo()));
      final session = (await repository.sessions()).firstWhere(
        (s) => s.confirmation == 'PENDING',
      );
      final key = commandKey();
      await repository.command(
        '/attendance/sessions/${session.id}/confirm',
        etag: session.etag,
        key: key,
      );
      await repository.command(
        '/attendance/sessions/${session.id}/confirm',
        etag: session.etag,
        key: key,
      );
      expect(
        (await repository.sessions())
            .firstWhere((s) => s.id == session.id)
            .confirmation,
        'CONFIRMED',
      );
      await expectLater(
        repository.command(
          '/attendance/sessions/${session.id}/reject',
          etag: session.etag,
        ),
        throwsA(isA<DataFailure>().having((e) => e.status, 'status', 412)),
      );
    },
  );
  test('approved correction updates attendance once and rejects stale approval replay', () async {
    final source = demo();
    final repository = HrRepository(ClientData.forTest(source));
    final record = await repository.create('correction', {
      'workDate': '2026-10-22',
      'newCheckIn': '2026-10-22T02:00:00Z',
      'newCheckOut': '2026-10-22T10:00:00Z',
      'reason': 'Forgot to clock out correctly',
    }, commandKey());
    source.setDemoRole('MANAGER');
    final key = commandKey();
    await repository.decide(record, 'approve', 'Confirmed with employee', key);
    await repository.decide(record, 'approve', 'Confirmed with employee', key);
    await expectLater(
      repository.decide(record, 'approve', 'Again', commandKey()),
      throwsA(isA<DataFailure>().having((e) => e.status, 'status', 412)),
    );
    source.setDemoRole('EMPLOYEE');
    final corrected = (await repository.sessions())
        .where((s) => s.source == 'MANUAL')
        .toList();
    expect(corrected, hasLength(1));
    expect(corrected.single.duration, const Duration(hours: 8));
  });
  test('workflow pages preserve total and expose every record', () async {
    final repository = HrRepository(ClientData.forTest(demo()));
    for (var i = 0; i < 26; i++) {
      await repository.create('request', {
        'title': 'Request $i',
        'reason': 'Review equipment needs',
      }, commandKey());
    }
    final first = await repository.recordsPage('request');
    final next = await repository.recordsPage('request', page: 1);
    expect(first.records, hasLength(25));
    expect(first.hasMore, true);
    expect(next.hasMore, false);
    expect({
      ...first.records.map((r) => r.id),
      ...next.records.map((r) => r.id),
    }, hasLength(first.total));
  });
  test('leave reserves balance, manager approval consumes it, rejection releases it, employee sees notification', () async {
    final source = demo();
    final repository = HrRepository(ClientData.forTest(source));
    final before = (await repository.balances()).firstWhere(
      (b) => b.id == 'annual',
    );
    final submitted = await repository.create('leave', {
      'leaveTypeId': 'annual',
      'startDate': '2026-11-02',
      'endDate': '2026-11-03',
      'halfDay': 'NONE',
      'reason': 'Family visit',
    }, commandKey());
    final pending = (await repository.balances()).firstWhere(
      (b) => b.id == 'annual',
    );
    expect(pending.pending, before.pending + 2);
    expect(pending.available, before.available - 2);
    await expectLater(
      repository.decide(submitted, 'approve', 'Looks good', commandKey()),
      throwsA(isA<DataFailure>().having((e) => e.status, 'status', 403)),
    );
    source.setDemoRole('MANAGER');
    expect(
      (await repository.records(
        'leave',
        pending: true,
      )).any((r) => r.id == submitted.id),
      true,
    );
    await repository.decide(submitted, 'approve', 'Approved', commandKey());
    source.setDemoRole('EMPLOYEE');
    final balance = (await repository.balances()).firstWhere(
      (b) => b.id == 'annual',
    );
    expect(balance.pending, before.pending);
    expect(balance.used, before.used + 2);
    expect(
      (await repository.inbox()).any((m) => m.recordId == submitted.id),
      true,
    );
    final next = await repository.create('leave', {
      'leaveTypeId': 'annual',
      'startDate': '2026-11-04',
      'endDate': '2026-11-04',
      'halfDay': 'NONE',
      'reason': 'Another appointment',
    }, commandKey());
    source.setDemoRole('MANAGER');
    await repository.decide(
      next,
      'reject',
      'Please choose a different day',
      commandKey(),
    );
    source.setDemoRole('EMPLOYEE');
    expect(
      (await repository.balances())
          .firstWhere((b) => b.id == 'annual')
          .available,
      balance.available,
    );
  });
  test('material request passes draft edit, submission, manager then HR approval and fulfillment', () async {
    final source = demo();
    final repository = HrRepository(ClientData.forTest(source));
    var record = await repository.create('request', {
      'title': 'External monitor',
      'type': 'MATERIAL',
      'items': [
        {'materialId': 'monitor', 'quantity': 1},
      ],
      'reason': 'Design reviews',
      'quantity': 1,
    }, commandKey());
    await repository.updateDraft(
      record,
      'Larger monitor',
      'For detailed design reviews',
    );
    record = await repository.detail('request', record.id);
    expect(record.title, 'Larger monitor');
    record = await repository.decide(record, 'submit', '', commandKey());
    source.setDemoRole('MANAGER');
    record = await repository.decide(
      record,
      'approve',
      'Useful for the role',
      commandKey(),
    );
    expect(record.status, 'PENDING');
    expect(record.fields['approvalStage'], 'HR');
    await expectLater(
      repository.decide(record, 'approve', 'Again', commandKey()),
      throwsA(isA<DataFailure>().having((e) => e.status, 'status', 403)),
    );
    source.setDemoRole('HR_ADMIN');
    record = await repository.decide(
      record,
      'approve',
      'Budget confirmed',
      commandKey(),
    );
    expect(record.status, 'APPROVED');
    record = await repository.decide(
      record,
      'fulfill',
      'Issued to employee',
      commandKey(),
    );
    expect(record.status, 'FULFILLED');
  });
  test('successful command replay survives restart without duplicating records or decisions', () async {
    final source = demo();
    JsonMap? persisted;
    source.onChanged = (data) async {
      persisted = data;
    };
    final key = commandKey();
    final input = DataRequest(
      'POST',
      '/requests',
      body: {
        'title': 'Remote day',
        'type': 'REMOTE_WORK',
        'reason': 'Home appointment',
      },
      idempotencyKey: key,
    );
    final first = await source.send(input);
    final restored = demo()..restore(persisted!);
    final replay = await restored.send(input);
    expect(replay.data, first.data);
    final records = await restored.send(
      const DataRequest('GET', '/requests/me'),
    );
    expect(
      (records.data['items'] as List).where((r) => r['id'] == first.data['id']),
      hasLength(1),
    );
  });
  test(
    'failed persistence rolls back demo mutation, leaving a safe retry',
    () async {
      final source = demo();
      source.onChanged = (_) async => throw StateError('disk full');
      final key = commandKey();
      final input = DataRequest(
        'POST',
        '/requests',
        body: {'title': 'Equipment', 'reason': 'Design reviews'},
        idempotencyKey: key,
      );
      await expectLater(source.send(input), throwsStateError);
      source.onChanged = null;
      final result = await source.send(input);
      expect(result.status, 201);
      final records = await source.send(
        const DataRequest('GET', '/requests/me'),
      );
      expect(
        (records.data['items'] as List).where((r) => r['title'] == 'Equipment'),
        hasLength(1),
      );
    },
  );
  test(
    'clock retry preserves occurrence time and body after an unknown outcome',
    () async {
      final source = UnknownClockSource();
      final repository = HrRepository(
        ClientData.forTest(source, store: MemorySecrets()),
      );
      final key = commandKey();
      await expectLater(
        repository.clock(key: key),
        throwsA(isA<DataFailure>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await repository.clock(key: key);
      expect(canonicalJson(source.bodies[0]), canonicalJson(source.bodies[1]));
    },
  );
}

class UnknownClockSource implements DataSource {
  @override
  String get mode => 'remote';
  final bodies = <JsonMap>[];
  @override
  Future<DataResponse> send(DataRequest r) async {
    bodies.add(r.body!);
    if (bodies.length == 1) throw const DataFailure(0, 'TIMEOUT', 'Unknown');
    return const DataResponse(201, {});
  }

  @override
  void close() {}
}
