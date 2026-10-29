import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/features/requests/data/repository.dart';
import 'package:hrflow_mobile/shared/domain/workflow.dart';

class AttachmentApi implements DataSource {
  final calls = <DataRequest>[];
  bool failed = false;
  bool foreign = false;
  @override
  String get mode => 'remote';
  @override
  Future<DataResponse> send(DataRequest r) async {
    calls.add(r);
    if (r.path.endsWith('/presign')) {
      return DataResponse(200, {
        'attachmentId': 'file-a',
        'uploadUrl':
            '/api/v1/requests/${foreign ? 'foreign' : 'request-a'}/attachments/file-a/upload',
      });
    }
    if (r.method == 'PUT') return const DataResponse(200, null);
    if (r.path.endsWith('/complete') && !failed) {
      failed = true;
      throw const DataFailure(0, 'TIMEOUT', 'Unknown outcome');
    }
    if (r.path.endsWith('/download')) {
      return const DataResponse(200, {
        'downloadUrl': '/api/v1/requests/request-a/attachments/file-a/file',
      });
    }
    if (r.path.endsWith('/file')) {
      return DataResponse(
        200,
        Uint8List.fromList([1, 2, 3]),
        cacheAllowed: false,
      );
    }
    return const DataResponse(200, {'id': 'file-a'});
  }

  @override
  void close() {}
}

const record = WorkflowRecord(
  id: 'request-a',
  employeeId: 'employee-a',
  title: 'Proof',
  status: 'DRAFT',
  reason: 'Context',
  kind: 'request',
  version: 0,
  fields: {},
  employeeName: 'Employee',
);
void main() {
  test('private file retries preserve reservation/completion identity and download through account transport', () async {
    final source = AttachmentApi();
    final client = ClientData.forTest(source);
    addTearDown(client.close);
    final repo = RequestsDataRepository(client);
    final bytes = Uint8List.fromList([1, 2, 3]);
    await expectLater(
      repo.attach(record, 'proof.pdf', bytes),
      throwsA(isA<DataFailure>().having((e) => e.code, 'code', 'TIMEOUT')),
    );
    await repo.attach(record, 'proof.pdf', bytes);
    expect(source.calls[0].idempotencyKey, source.calls[3].idempotencyKey);
    expect(source.calls[2].idempotencyKey, source.calls[5].idempotencyKey);
    expect(await repo.download(record, {'id': 'file-a'}), [1, 2, 3]);
    expect(source.calls.last.responseType, 'bytes');
  });
  test(
    'foreign private upload path is rejected before bytes are sent',
    () async {
      final source = AttachmentApi()..foreign = true;
      final client = ClientData.forTest(source);
      addTearDown(client.close);
      await expectLater(
        RequestsDataRepository(client)
            .attach(record, 'proof.pdf', Uint8List.fromList([1])),
        throwsA(
          isA<DataFailure>().having((e) => e.code, 'code', 'INVALID_FILE_URL'),
        ),
      );
      expect(source.calls.length, 1);
    },
  );
}
