import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/demo/local_service.dart';
import 'package:hrflow_mobile/core/protocol.dart';

LocalDataSource _source() => LocalDataSource(
  jsonDecode(File('assets/data/demo-seed.json').readAsStringSync()) as JsonMap,
  populate: true,
  now: () => DateTime.utc(2026, 10, 23, 3),
);

DataRequest _create(String key, {String delegateId = 'demo-hr'}) => DataRequest(
  'POST',
  '/approvals/delegations',
  idempotencyKey: key,
  body: {
    'delegateId': delegateId,
    'startsOn': '2026-10-23',
    'endsOn': '2026-10-30',
    'reason': 'Annual leave coverage',
  },
);

void main() {
  test(
    'delegation requires a manager and excludes self from candidates',
    () async {
      final source = _source();
      await expectLater(
        source.send(const DataRequest('GET', '/approvals/eligible-delegates')),
        throwsA(isA<DataFailure>().having((e) => e.status, 'status', 403)),
      );
      source.setDemoRole('MANAGER');
      final response = await source.send(
        const DataRequest('GET', '/approvals/eligible-delegates'),
      );
      final ids = (response.data['items'] as List)
          .map((row) => row['id'])
          .toList();
      expect(ids, contains('demo-hr'));
      expect(ids, isNot(contains('demo-manager')));
    },
  );

  test(
    'create is idempotent, rejects overlap and enforces ownership',
    () async {
      final source = _source()..setDemoRole('MANAGER');
      final key = commandKey();
      final first = await source.send(_create(key));
      final repeated = await source.send(_create(key));
      expect(repeated.data['id'], first.data['id']);
      await expectLater(
        source.send(_create(commandKey(), delegateId: 'demo-owner')),
        throwsA(isA<DataFailure>().having((e) => e.status, 'status', 409)),
      );
      final id = first.data['id'] as String;
      source.setDemoRole('HR_ADMIN');
      await expectLater(
        source.send(
          DataRequest('DELETE', '/approvals/delegations/$id', ifMatch: '"1"'),
        ),
        throwsA(isA<DataFailure>().having((e) => e.status, 'status', 404)),
      );
      source.setDemoRole('MANAGER');
      await source.send(
        DataRequest('DELETE', '/approvals/delegations/$id', ifMatch: '"1"'),
      );
      final list = await source.send(
        const DataRequest('GET', '/approvals/delegations'),
      );
      expect((list.data['items'] as List).single['status'], 'CANCELLED');
    },
  );
}
