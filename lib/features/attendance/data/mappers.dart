import 'package:hrflow_mobile/core/data/json.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/attendance/domain/models.dart';

abstract final class WorkSessionMapper {
  static WorkSession fromJson(JsonMap j) => WorkSession(
    id: requiredText(j, 'id'),
    employeeId: j['employeeId'] as String? ?? '',
    clockIn: timestamp(j, j['checkInAt'] != null ? 'checkInAt' : 'clockIn'),
    clockOut: j['checkOutAt'] == null && j['clockOut'] == null
        ? null
        : timestamp(j, j['checkOutAt'] != null ? 'checkOutAt' : 'clockOut'),
    version: requiredInt(j, 'version'),
    revisionToken: j['etag'] as String?,
    source: j['source'] as String? ?? 'TAP',
    confirmation: j['confirmStatus'] as String? ?? 'NONE',
  );
}
