import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';

import 'support/workspace_fixture.dart';

class LeaveOwnerServer implements DataSource {
  final requests = <DataRequest>[];
  @override
  String get mode => 'remote';
  @override
  Future<DataResponse> send(DataRequest request) async {
    requests.add(request);
    if (request.path == '/leave/types') {
      return const DataResponse(200, {
        'items': [
          {'id': 'type-uuid', 'code': 'ANNUAL', 'name': 'Annual'},
        ],
        'page': 0,
        'size': 100,
        'total': 1,
      });
    }
    if (request.path == '/leave/balances/me') {
      return const DataResponse(200, {
        'items': [
          {
            'id': 'balance-uuid',
            'type': 'ANNUAL',
            'name': 'Annual',
            'entitled': 15,
            'used': 2,
            'pending': 1,
            'available': 12,
            'year': 2026,
          },
        ],
        'page': 0,
        'size': 100,
        'total': 1,
      });
    }
    if (request.path.endsWith('/preview')) {
      return const DataResponse(200, {
        'chargeableDays': 1,
        'balanceTracked': true,
        'balanceBefore': 12,
        'balanceAfter': 11,
        'allowHalfDay': true,
        'evidenceRequired': false,
        'minimumNoticeDays': 0,
        'warnings': <String>[],
      });
    }
    return const DataResponse(201, {
      'id': 'leave',
      'employeeId': 'employee',
      'type': 'ANNUAL',
      'status': 'PENDING',
      'version': 0,
    }, etag: '"owner-etag"');
  }

  @override
  void close() {}
}

void main() {
  test(
    'selected catalog ID is resolved to owner type code for preview and submit',
    () async {
      final server = LeaveOwnerServer();
      final repository = HrRepository(ClientData.forTest(server));
      await repository.preview(
        'type-uuid',
        '2026-11-02',
        '2026-11-02',
        'FULL_DAY',
      );
      final key = commandKey();
      final submitted = await repository.create('leave', {
        'leaveTypeId': 'type-uuid',
        'startDate': '2026-11-02',
        'endDate': '2026-11-02',
        'portion': 'FULL_DAY',
        'reason': 'Personal',
      }, key);
      for (final request in server.requests.where((r) => r.method == 'POST')) {
        expect(request.body?['type'], 'ANNUAL');
        expect(request.body?.containsKey('leaveTypeId'), isFalse);
      }
      expect(server.requests.last.idempotencyKey, key);
      expect(submitted.etag, '"owner-etag"');
    },
  );

  test('unknown catalog selection fails before sending any command', () async {
    final server = LeaveOwnerServer();
    final repository = HrRepository(ClientData.forTest(server));
    await expectLater(
      repository.preview('missing', '2026-11-02', '2026-11-02', 'FULL_DAY'),
      throwsA(isA<DataFailure>()),
    );
    expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  test(
    'owner balance type code is decoded without requiring the demo-only field',
    () async {
      final balances = await HrRepository(
        ClientData.forTest(LeaveOwnerServer()),
      ).balances();
      expect(balances.single.id, 'ANNUAL');
      expect(balances.single.available, 12);
      expect(balances.single.year, 2026);
    },
  );
}
