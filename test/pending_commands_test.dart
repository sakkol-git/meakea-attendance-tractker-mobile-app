import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/data/pending_commands.dart';
import 'package:hrflow_mobile/core/data/storage.dart';
import 'package:hrflow_mobile/core/demo/local_service.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/app/runtime.dart';
import 'package:hrflow_mobile/core/protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'a pending command survives process recreation and reuses its key',
    () async {
      final store = MemorySecrets();
      final first = PendingCommandKeys(store, 'account');
      final key = await first.acquire('tenant:alice:approve:42', {
        'etag': '"2"',
        'note': 'Approved',
      });
      final restarted = PendingCommandKeys(store, 'account');
      expect(
        await restarted.acquire('tenant:alice:approve:42', {
          'note': 'Approved',
          'etag': '"2"',
        }),
        key,
      );
      expect(
        await restarted.acquire('tenant:alice:approve:42', {
          'etag': '"3"',
          'note': 'Approved',
        }),
        isNot(key),
      );
    },
  );

  test('logout erases all pending command keys', () async {
    final store = MemorySecrets();
    final keys = PendingCommandKeys(store, 'account');
    final prior = await keys.acquire('tenant:alice:approve:42', {
      'note': 'Yes',
    });
    await keys.clearAll();
    expect(
      await PendingCommandKeys(
        store,
        'account',
      ).acquire('tenant:alice:approve:42', {'note': 'Yes'}),
      isNot(prior),
    );
  });

  test('signing out of the demo account wipes its pending keys', () async {
    final secrets = MemorySecrets();
    final client = await ClientData.create(
      secrets: secrets,
      persistDemo: false,
    );
    addTearDown(client.close);
    await client.demoLogin('MANAGER');
    final keys = PendingCommandKeys(secrets, client.namespace);
    final before = await keys.acquire('demo:manager:decision', {'note': 'yes'});
    await client.logout();
    expect(
      await keys.acquire('demo:manager:decision', {'note': 'yes'}),
      isNot(before),
    );
  });

  test('write failures distinguish conflict, failed and uncertain', () {
    expect(
      writeFailureKind(const DataFailure(412, 'STALE_VERSION', 'Changed')),
      WriteFailureKind.conflict,
    );
    expect(
      writeFailureKind(const DataFailure(422, 'INVALID', 'Invalid')),
      WriteFailureKind.failed,
    );
    expect(
      writeFailureKind(const DataFailure(0, 'TIMEOUT', 'Unknown')),
      WriteFailureKind.unknown,
    );
  });

  test(
    'lost response after commit replays one non-clock receipt after restart',
    () async {
      final seed = jsonDecode(
        await rootBundle.loadString('assets/data/demo-seed.json'),
      ) as JsonMap;
      final source = LocalDataSource(seed);
      addTearDown(source.close);
      final store = MemorySecrets();
      final keys = PendingCommandKeys(store, 'session');
      const scope = 'tenant:employee:leave:create';
      const body = <String, dynamic>{'reason': 'Appointment'};
      final firstKey = await keys.acquire(scope, body);
      DataResponse? committed;
      Future<void> loseResponse() async {
        committed = await source.send(
          DataRequest(
            'POST',
            '/leave/requests',
            body: body,
            idempotencyKey: firstKey,
          ),
        );
        throw const DataFailure(0, 'TIMEOUT', 'Response lost after commit');
      }

      await expectLater(loseResponse(), throwsA(isA<DataFailure>()));
      final retryKey = await PendingCommandKeys(
        store,
        'session',
      ).acquire(scope, body);
      expect(retryKey, firstKey);
      final replay = await source.send(
        DataRequest(
          'POST',
          '/leave/requests',
          body: body,
          idempotencyKey: retryKey,
        ),
      );
      expect(replay.data, committed!.data);
      final listing = await source.send(
        const DataRequest('GET', '/leave/requests/me'),
      );
      final ids = (listing.data['items'] as List).map((row) => row['id']);
      expect(ids.where((id) => id == committed!.data['id']).length, 1);
    },
  );
}
