import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';

import 'support/workspace_fixture.dart';

import 'package:hrflow_mobile/core/data/mappers.dart';

class ContractServer implements DataSource {
  @override
  String get mode => 'remote';
  final pages = <int>[];
  String? match;
  DataRequest? lastRequest;
  final row = <String, dynamic>{
    'id': 'record-a',
    'employeeId': 'employee-a',
    'status': 'PENDING',
    'version': 1,
  };
  @override
  Future<DataResponse> send(DataRequest r) async {
    lastRequest = r;
    if (r.path == '/auth/profile' && r.method == 'PATCH') {
      return DataResponse(200, {
        'userId': 'user-a',
        'employeeId': 'employee-a',
        'tenantId': 'tenant-a',
        'name': r.body!['name'],
        'roles': ['EMPLOYEE'],
        'timeZone': r.body!['timeZone'],
      });
    }
    if (r.method == 'POST') {
      match = r.ifMatch;
      return DataResponse(200, row, etag: '"opaque-command-revision"');
    }
    if (r.query.isNotEmpty) {
      final page = int.parse(r.query['page']!);
      pages.add(page);
      return DataResponse(200, {
        'items': page == 0
            ? List.generate(100, (i) => {'id': '$i'})
            : [
                {'id': '100'},
              ],
        'total': 101,
      });
    }
    return DataResponse(200, row, etag: '"opaque-revision-abc"');
  }

  @override
  void close() {}
}

void main() {
  test('detail command preserves the exact opaque server ETag', () async {
    final server = ContractServer();
    final repository = HrRepository(ClientData.forTest(server));
    final record = await repository.detail('request', 'record-a');
    final decided = await repository.decide(
      record,
      'approve',
      'Reviewed',
      commandKey(),
    );
    expect(decided.etag, '"opaque-command-revision"');
    expect(server.match, '"opaque-revision-abc"');
  });
  test('profile update uses the implemented auth contract', () async {
    final server = ContractServer();
    final profile = await HrRepository(ClientData.forTest(server))
        .saveProfile({'name': 'Updated User', 'timeZone': 'Asia/Tokyo'});

    expect(server.lastRequest?.method, 'PATCH');
    expect(server.lastRequest?.path, '/auth/profile');
    expect(server.lastRequest?.body, {
      'name': 'Updated User',
      'timeZone': 'Asia/Tokyo',
    });
    expect(profile.name, 'Updated User');
    expect(profile.timeZone, 'Asia/Tokyo');
  });
  test(
    'remote catalogue pagination does not truncate the first page',
    () async {
      final server = ContractServer();
      final rows = await HrRepository(ClientData.forTest(server))
          .collection('/employees');
      expect(rows, hasLength(101));
      expect(server.pages, [0, 1]);
    },
  );
  test('malformed dates and amounts fail as contract errors', () {
    expect(
      () => WorkSessionMapper.fromJson({
        'id': 'x',
        'checkInAt': 'bad',
        'version': 1,
      }),
      throwsA(isA<DataFailure>()),
    );
    expect(
      () => LeaveBalanceMapper.fromJson({
        'leaveTypeId': 'annual',
        'entitled': '18',
      }),
      throwsA(isA<DataFailure>()),
    );
  });
  test('nested workflow payload is immutable', () {
    final record = WorkflowRecordMapper.fromJson({
      'id': 'x',
      'employeeId': 'e',
      'status': 'PENDING',
      'version': 1,
      'decisions': [
        {'note': 'Reviewed'},
      ],
    }, 'request');
    expect(
      () => (record.fields['decisions'] as List).clear(),
      throwsUnsupportedError,
    );
    expect(
      () => (record.fields['decisions'][0] as Map)['note'] = 'Changed',
      throwsUnsupportedError,
    );
  });
}
