import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/features/workflows/data/mappers.dart';

void main() {
  test('provider attachment metadata retains the actual filename and size in record presentation', () {
    final record = WorkflowRecordMapper.fromJson({
      'id': 'request-a',
      'employeeId': 'employee-a',
      'status': 'DRAFT',
      'version': 0,
      'attachments': [
        {
          'id': 'file-a',
          'fileName': 'actual-proof.pdf',
          'fileSize': 1234,
          'contentType': 'application/pdf',
          'status': 'FINALIZED',
        },
      ],
    }, 'request');
    final file = (record.fields['attachments'] as List).single as Map;
    expect(file['name'], 'actual-proof.pdf');
    expect(file['size'], 1234);
    expect(file['id'], 'file-a');
  });
  test(
    'editing a provider material draft retains its persisted line selections',
    () {
      final record = WorkflowRecordMapper.fromJson({
        'id': 'request-a',
        'employeeId': 'employee-a',
        'status': 'DRAFT',
        'version': 0,
        'lines': [
          {'id': 'line-a', 'materialItemId': 'material-a', 'quantity': 2},
        ],
      }, 'request');
      expect(
        (record.fields['items'] as List).single['materialId'],
        'material-a',
      );
    },
  );
}
