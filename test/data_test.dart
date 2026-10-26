import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/core/demo/local_service.dart';
import 'package:hrflow_mobile/core/data/remote_source.dart';
import 'package:hrflow_mobile/core/protocol.dart';

Matcher failure(int status, String code) => isA<DataFailure>()
    .having((e) => e.status, 'status', status)
    .having((e) => e.code, 'code', code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('leave cancellation and correction rejection', () async {
    final seed = jsonDecode(
      File('assets/data/demo-seed.json').readAsStringSync(),
    ) as JsonMap;
    for (final scenario in [
      ('/leave/requests', 'cancel', 'EMPLOYEE', 'CANCELLED'),
      ('/attendance/corrections', 'reject', 'MANAGER', 'REJECTED'),
    ]) {
      final source = LocalDataSource(seed);
      final created = await source.send(
        DataRequest(
          'POST',
          scenario.$1,
          body: {'reason': 'Demo'},
          idempotencyKey: commandKey(),
        ),
      );
      source.setDemoRole(scenario.$3);
      final result = await source.send(
        DataRequest(
          'POST',
          '${scenario.$1}/${created.data['id']}/${scenario.$2}',
          ifMatch: created.etag,
          idempotencyKey: commandKey(),
        ),
      );
      expect(result.data['status'], scenario.$4);
    }
  });
  LocalDataSource local({DateTime Function()? now}) => LocalDataSource(
    jsonDecode(File('assets/data/demo-seed.json').readAsStringSync())
        as JsonMap,
    now: now,
  );

  test(
    'local password change matches the canonical success response',
    () async {
      final result = await local().send(
        DataRequest(
          'POST',
          '/auth/change-password',
          body: {
            'currentPassword': 'current-password',
            'newPassword': 'replacement-password',
          },
          idempotencyKey: commandKey(),
        ),
      );

      expect(result.status, 200);
      expect(result.data, {'message': 'Password changed.'});
    },
  );

  test(
    'local profile update uses the canonical auth route and fields',
    () async {
      final result = await local().send(
        DataRequest(
          'PATCH',
          '/auth/profile',
          body: {'name': 'Updated User', 'timeZone': 'Asia/Tokyo'},
        ),
      );

      expect(result.status, 200);
      expect(result.data['name'], 'Updated User');
      expect(result.data['timeZone'], 'Asia/Tokyo');
    },
  );

  test('local replay, conflicting body, role/version guards, notification and isolated reads', () async {
    final source = local();
    final key = commandKey();
    final created = await source.send(
      DataRequest(
        'POST',
        '/leave/requests',
        body: {'reason': 'Appointment'},
        idempotencyKey: key,
      ),
    );
    final replay = await source.send(
      DataRequest(
        'POST',
        '/leave/requests',
        body: {'reason': 'Appointment'},
        idempotencyKey: key,
      ),
    );
    expect(replay.data, created.data);
    await expectLater(
      source.send(
        DataRequest(
          'POST',
          '/leave/requests',
          body: {'reason': 'Changed'},
          idempotencyKey: key,
        ),
      ),
      throwsA(failure(409, 'IDEMPOTENCY_CONFLICT')),
    );
    final path = '/leave/requests/${created.data['id']}/approve';
    await expectLater(
      source.send(
        DataRequest(
          'POST',
          path,
          ifMatch: created.etag,
          idempotencyKey: commandKey(),
        ),
      ),
      throwsA(failure(403, 'FORBIDDEN')),
    );
    source.setDemoRole('MANAGER');
    await expectLater(
      source.send(DataRequest('POST', path, idempotencyKey: commandKey())),
      throwsA(failure(428, 'VERSION_REQUIRED')),
    );
    final approved = await source.send(
      DataRequest(
        'POST',
        path,
        ifMatch: created.etag,
        idempotencyKey: commandKey(),
      ),
    );
    expect(approved.data['status'], 'APPROVED');
    expect(approved.etag, '"2"');
    await expectLater(
      source.send(
        DataRequest(
          'POST',
          path,
          ifMatch: created.etag,
          idempotencyKey: commandKey(),
        ),
      ),
      throwsA(failure(412, 'STALE_VERSION')),
    );
    await expectLater(
      source.send(
        DataRequest(
          'POST',
          path,
          ifMatch: approved.etag,
          idempotencyKey: commandKey(),
        ),
      ),
      throwsA(failure(409, 'INVALID_TRANSITION')),
    );
    expect(
      (await source.send(const DataRequest('GET', '/notifications')))
          .data['total'],
      1,
    );
    approved.data['status'] = 'TAMPERED';
    expect(
      (await source.send(
        DataRequest('GET', '/leave/requests/${created.data['id']}'),
      )).data['status'],
      'APPROVED',
    );
  });

  test(
    'attendance is stateful, replay safe, uses company date and resets',
    () async {
      final source = local(now: () => DateTime.parse('2026-10-23T20:00:00Z'));
      final key = commandKey();
      final started = await source.send(
        DataRequest('POST', '/attendance/check-in', idempotencyKey: key),
      );
      expect(
        (await source.send(
          DataRequest('POST', '/attendance/check-in', idempotencyKey: key),
        )).data,
        started.data,
      );
      await expectLater(
        source.send(
          DataRequest(
            'POST',
            '/attendance/check-in',
            idempotencyKey: commandKey(),
          ),
        ),
        throwsA(failure(409, 'SESSION_ALREADY_OPEN')),
      );
      final today = await source.send(
        const DataRequest('GET', '/attendance/today'),
      );
      expect(today.data['date'], '2026-10-24');
      expect(today.data['sessions'], hasLength(1));
      expect(
        (await source.send(
          DataRequest(
            'POST',
            '/attendance/check-out',
            idempotencyKey: commandKey(),
            ifMatch: started.etag,
          ),
        )).data['clockOut'],
        isNotNull,
      );
      source.reset();
      expect(
        (await source.send(const DataRequest('GET', '/attendance/me')))
            .data['total'],
        0,
      );
    },
  );

  test('general request progresses from draft through fulfillment', () async {
    final source = local();
    var result = await source.send(
      DataRequest(
        'POST',
        '/requests',
        body: {'title': 'Monitor'},
        idempotencyKey: commandKey(),
      ),
    );
    final id = result.data['id'];
    for (final step in [
      ('submit', 'EMPLOYEE', 'PENDING'),
      ('approve', 'MANAGER', 'APPROVED'),
      ('fulfill', 'HR_ADMIN', 'FULFILLED'),
    ]) {
      source.setDemoRole(step.$2);
      result = await source.send(
        DataRequest(
          'POST',
          '/requests/$id/${step.$1}',
          ifMatch: result.etag,
          idempotencyKey: commandKey(),
        ),
      );
      expect(result.data['status'], step.$3);
    }
  });

  test(
    'explicit mode, isolated state, keys required and unsupported routes fail',
    () async {
      final client = await ClientData.create(persistDemo: false);
      expect(client.source.mode, 'local');
      client.close();
      await expectLater(
        ClientData.create(mode: 'typo'),
        throwsA(failure(0, 'INVALID_MODE')),
      );
      await expectLater(
        ClientData.create(mode: 'remote'),
        throwsA(failure(0, 'INVALID_BASE_URL')),
      );
      final source = local();
      await expectLater(
        source.send(
          const DataRequest('POST', '/requests', body: {'title': 'Monitor'}),
        ),
        throwsA(failure(428, 'IDEMPOTENCY_REQUIRED')),
      );
      await expectLater(
        source.send(const DataRequest('GET', '/unsupported/operation')),
        throwsA(failure(501, 'DEMO_NOT_IMPLEMENTED')),
      );
      await expectLater(
        source.send(
          const DataRequest(
            'GET',
            '/requests/me',
            query: {'status': 'PENDING'},
          ),
        ),
        throwsA(failure(501, 'DEMO_NOT_IMPLEMENTED')),
      );
      expect(
        (await local().send(const DataRequest('GET', '/requests/me')))
            .data['total'],
        0,
      );
    },
  );

  test('remote wire headers, query, etag, rotated bearer and 204', () async {
    var token = 'test-token';
    var count = 0;
    final key = commandKey();
    final source = RemoteDataSource(
      'https://example.test/api/v1/',
      () => token,
      client: MockClient((r) async {
        expect(r.url.path, '/api/v1/requests');
        expect(r.url.queryParameters['search'], 'a & b');
        expect(r.headers['Authorization'], 'Bearer $token');
        expect(r.headers['Idempotency-Key'], key);
        expect(r.headers['If-Match'], '"3"');
        expect(r.followRedirects, isFalse);
        count++;
        return count == 1
            ? http.Response('{"id":"r1"}', 201, headers: {'etag': '"4"'})
            : http.Response('', 204);
      }),
    );
    final r = DataRequest(
      'POST',
      '/requests',
      body: {'title': 'Monitor'},
      query: {'search': 'a & b'},
      idempotencyKey: key,
      ifMatch: '"3"',
    );
    expect((await source.send(r)).etag, '"4"');
    token = 'rotated-test-token';
    expect((await source.send(r)).data, isNull);
    source.close();
  });

  test('remote problems, invalid JSON, network and timeout do not fall back', () async {
    var count = 0;
    final source = RemoteDataSource(
      'https://example.test/api/v1',
      () => null,
      client: MockClient((r) async {
        count++;
        return http.Response(
          '{"code":"STALE_VERSION","detail":"Refresh","traceId":"trace-test"}',
          412,
        );
      }),
    );
    await expectLater(
      source.send(const DataRequest('GET', '/auth/me')),
      throwsA(failure(412, 'STALE_VERSION')),
    );
    expect(count, 1);
    source.close();
    final bad = RemoteDataSource(
      'https://example.test/api/v1',
      () => null,
      client: MockClient((r) async => http.Response('<html>bad</html>', 200)),
    );
    await expectLater(
      bad.send(const DataRequest('GET', '/auth/me')),
      throwsA(failure(200, 'INVALID_RESPONSE')),
    );
    bad.close();
    final offline = RemoteDataSource(
      'https://example.test/api/v1',
      () => null,
      client: MockClient((r) async => throw http.ClientException('offline')),
    );
    await expectLater(
      offline.send(const DataRequest('GET', '/auth/me')),
      throwsA(failure(0, 'NETWORK_ERROR')),
    );
    offline.close();
    final slow = RemoteDataSource(
      'https://example.test/api/v1',
      () => null,
      timeout: Duration.zero,
      client: MockClient((r) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      slow.send(const DataRequest('GET', '/auth/me')),
      throwsA(failure(0, 'TIMEOUT')),
    );
    slow.close();
    expect(
      () => RemoteDataSource('http://example.test/api/v1', () => null),
      throwsA(failure(0, 'INVALID_BASE_URL')),
    );
  });
}
