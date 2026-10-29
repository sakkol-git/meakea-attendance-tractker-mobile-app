import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/features/requests/data/repository.dart';

class NoDraftApi implements DataSource {
  final requests = <DataRequest>[];
  @override
  String get mode => 'remote';
  @override
  Future<DataResponse> send(DataRequest r) async {
    requests.add(r);
    throw const DataFailure(404, 'NOT_FOUND', 'No draft endpoint.');
  }

  @override
  void close() {}
}

void main() {
  test('current remote backend declares unsaved form recovery unavailable, before any network call', () async {
    final source = NoDraftApi();
    final client = ClientData.forTest(source);
    addTearDown(client.close);
    final repository = RequestsDataRepository(client);
    expect(repository.supportsFormDrafts, isFalse);
    await expectLater(
      repository.clearFormDraft('request'),
      throwsA(
        isA<DataFailure>().having(
          (e) => e.code,
          'code',
          'DRAFT_RECOVERY_UNAVAILABLE',
        ),
      ),
    );
    expect(source.requests, isEmpty);
  });
}
