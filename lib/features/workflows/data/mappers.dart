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
        fields: freeze(j) as JsonMap,
        employeeName: j['employeeName'] as String? ?? 'Employee',
      );
}
