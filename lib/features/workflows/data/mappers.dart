import 'package:hrflow_mobile/core/data/json.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/shared/domain/workflow.dart';

abstract final class WorkflowRecordMapper {
  static WorkflowRecord fromJson(JsonMap j, String kind, {String? etag}) =>
      WorkflowRecord(
        id: requiredText(j, 'id'),
        employeeId: requiredText(j, 'employeeId'),
        title:
            j['title'] as String? ??
            j['typeName'] as String? ??
            (kind == 'leave'
                ? 'Leave request'
                : kind == 'correction'
                ? 'Attendance correction'
                : 'Request'),
        status: requiredText(j, 'status'),
        reason: j['reason'] as String? ?? j['description'] as String? ?? '',
        kind: kind,
        version: requiredInt(j, 'version'),
        revisionToken: etag ?? j['etag'] as String?,
        fields: freeze(_fields(j, kind)) as JsonMap,
        employeeName: j['employeeName'] as String? ?? 'Employee',
      );

  static JsonMap _fields(JsonMap j, String kind) => {
    ...j,
    if (kind == 'request' && j['items'] == null && j['lines'] is List)
      'items': [
        for (final raw in j['lines'] as List)
          {...object(raw), 'materialId': object(raw)['materialItemId']},
      ],
    if (kind == 'correction') ...{
      'workDate': j['date'] ?? j['workDate'],
      'newCheckIn': j['proposedClockIn'] ?? j['newCheckIn'],
      'newCheckOut': j['proposedClockOut'] ?? j['newCheckOut'],
    },
    if (j['attachments'] is List)
      'attachments': [
        for (final raw in j['attachments'] as List)
          {
            ...object(raw),
            'name': object(raw)['fileName'] ?? object(raw)['name'],
            'size': object(raw)['fileSize'] ?? object(raw)['size'],
          },
      ],
  };
}
