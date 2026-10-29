import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';

import 'support/workspace_fixture.dart';

class CorrectionServer implements DataSource {
  DataRequest? received;
  @override
  String get mode => 'remote';
  @override
  Future<DataResponse> send(DataRequest request) async {
    received = request;
    return const DataResponse(201, {
      'id': 'correction',
      'employeeId': 'employee',
      'status': 'PENDING',
      'reason': 'Forgot to tap at the office.',
      'date': '2026-10-28',
      'proposedClockIn': '2026-10-28T01:00:00Z',
      'proposedClockOut': '2026-10-28T10:00:00Z',
      'version': 0,
    }, etag: '"opaque-revision"');
  }

  @override
  void close() {}
}

void main() {
  test('actual mobile correction adapter uses owner field names and preserves reviewer time fields', () async {
    final server = CorrectionServer();
    final key = commandKey();
    final row = await HrRepository(ClientData.forTest(server))
        .create('correction', {
          'workDate': '2026-10-28',
          'newCheckIn': '2026-10-28T01:00:00Z',
          'newCheckOut': '2026-10-28T10:00:00Z',
          'reason': 'Forgot to tap at the office.',
        }, key);
    expect(server.received?.body, {
      'date': '2026-10-28',
      'proposedClockIn': '2026-10-28T01:00:00Z',
      'proposedClockOut': '2026-10-28T10:00:00Z',
      'reason': 'Forgot to tap at the office.',
    });
    expect(server.received?.idempotencyKey, key);
    expect(row.fields['workDate'], '2026-10-28');
    expect(row.fields['newCheckIn'], '2026-10-28T01:00:00Z');
    expect(row.etag, '"opaque-revision"');
  });
}
