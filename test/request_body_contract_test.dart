import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/features/requests/data/repository.dart';

class RequestApi implements DataSource {
  DataRequest? last;
  @override
  String get mode => 'remote';
  @override
  Future<DataResponse> send(DataRequest r) async {
    last = r;
    return const DataResponse(201, {
      'id': 'request-a',
      'employeeId': 'employee-a',
      'version': 0,
      'status': 'DRAFT',
    });
  }

  @override
  void close() {}
}

void main() {
  test('remote non-material request sends canonical positive quantity rather than null', () async {
    final source = RequestApi();
    final client = ClientData.forTest(source);
    addTearDown(client.close);
    await RequestsDataRepository(client).create('request', {
      'title': 'Remote work',
      'type': 'REMOTE_WORK',
      'reason': 'Scheduled work',
      'quantity': null,
    }, commandKey());
    expect(source.last!.body!['quantity'], 1);
  });
}
