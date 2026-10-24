import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/data/storage.dart';
import 'package:hrflow_mobile/core/data/cache/cached_source.dart';
import 'package:hrflow_mobile/core/data/cache/store.dart';
import 'package:hrflow_mobile/core/demo/local_service.dart';
import 'package:hrflow_mobile/features/attendance/data/repository.dart';
import 'package:hrflow_mobile/features/identity/data/repository.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';

class GatedSecrets extends MemorySecrets {
  final entered = Completer<void>(), release = Completer<void>();
  @override
  Future<String?> read(String key) async {
    if (key == 'hrflow.device') {
      if (!entered.isCompleted) entered.complete();
      await release.future;
    }
    return super.read(key);
  }
}

class ConflictServer implements DataSource {
  int revision = 1;
  @override
  String get mode => 'remote';
  @override
  Future<DataResponse> send(DataRequest request) async {
    if (request.method != 'GET') {
      throw const DataFailure(412, 'STALE_VERSION', 'Refresh the record.');
    }
    return DataResponse(200, {'version': revision});
  }

  @override
  void close() {}
}

JsonMap seed() =>
    jsonDecode(File('assets/data/demo-seed.json').readAsStringSync())
        as JsonMap;
void main() {
  test(
    'a stale version invalidates fresh read cache before the next review',
    () async {
      final upstream = ConflictServer();
      final cache = CachedDataSource(upstream, MemoryCacheStore());
      await cache.bind('tenant:employee:hr');
      expect(
        (await cache.send(const DataRequest('GET', '/leave/admin/balances')))
            .data['version'],
        1,
      );
      upstream.revision = 2;
      await expectLater(
        cache.send(
          DataRequest(
            'POST',
            '/leave/admin/balances/employee-a/adjust',
            idempotencyKey: commandKey(),
            ifMatch: '"1"',
          ),
        ),
        throwsA(isA<DataFailure>().having((e) => e.status, 'status', 412)),
      );
      expect(
        (await cache.send(const DataRequest('GET', '/leave/admin/balances')))
            .data['version'],
        2,
      );
      cache.close();
    },
  );
  test('an account switch during device storage cannot submit old evidence under a new identity', () async {
    final source = LocalDataSource(seed(), populate: true),
        secrets = GatedSecrets();
    final client = ClientData.forTest(source, store: secrets),
        repo = AttendanceDataRepository(ClientData.forTest(source));
    final repository = AttendanceDataRepository(client);
    final pending = repository.changeCase('attendance.capture', null, {
      'latitude': 11.5564,
      'longitude': 104.9282,
      'accuracyMeters': 15,
      'capturedAt': '2026-10-23T03:00:00Z',
      'kind': 'GEOFENCE_ENTER',
      'siteId': 'site-headquarters',
    }, key: commandKey());
    final expectation = expectLater(
      pending,
      throwsA(
        isA<DataFailure>().having((e) => e.code, 'code', 'SESSION_CHANGED'),
      ),
    );
    await secrets.entered.future;
    await client.demoLogin('HR_ADMIN');
    secrets.release.complete();
    await expectation;
    expect(await repo.cases('attendance.evidence'), isEmpty);
  });
  test(
    'arrival exactly at grace is on time; one second beyond grace is late',
    () async {
      for (final seconds in [0, 1]) {
        final source = LocalDataSource(
          seed(),
          populate: true,
          now: () => DateTime.utc(2026, 10, 23, 1, 40, seconds),
        );
        final client = ClientData.forTest(source),
            attendance = AttendanceDataRepository(ClientData.forTest(source));
        source.setDemoRole('HR_ADMIN');
        await IdentityDataRepository(client).assignShift(
          'demo-employee',
          'shift-standard',
          '2026-10-23',
          '2026-10-23',
          commandKey(),
        );
        source.setDemoRole('EMPLOYEE');
        await attendance.clock(key: commandKey());
        final day = (await attendance.cases('attendance.days')).single;
        expect(day.values['lateMinutes'], seconds == 0 ? 0 : 11);
      }
    },
  );
}
