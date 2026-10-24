import '../../../core/protocol.dart';
import 'case_routes.dart';

import 'package:hrflow_mobile/core/data/case_repository.dart';
import 'package:hrflow_mobile/core/data/resource_repository.dart';

import '../domain/repository.dart';

import 'package:hrflow_mobile/features/workflows/data/methods.dart';
import 'package:hrflow_mobile/features/attachments/data/methods.dart';
import 'package:hrflow_mobile/features/attendance/data/methods.dart';

class AttendanceDataRepository extends ResourceRepository
    with CaseMethods, WorkflowsMethods, AttachmentsMethods, AttendanceMethods
    implements AttendanceRepository {
  @override
  Map<String, CaseRoute> get caseRoutes => attendanceCaseRoutes;

  AttendanceDataRepository(super.client);
  @override
  Future<JsonMap> changeCase(
    String action,
    String? id,
    JsonMap input, {
    required String key,
    String? etag,
  }) async {
    if (action != 'attendance.capture') {
      return super.changeCase(action, id, input, key: key, etag: etag);
    }
    final workspace = client.workspaceRevision;
    final device = await client.secrets.read('hrflow.device') ?? commandKey();
    await client.secrets.write('hrflow.device', device);
    requireWorkspace(workspace);
    return super.changeCase(
      action,
      id,
      {
        'items': [
          {
            'eventId': key,
            'kind': input['kind'],
            'occurredAt': input['capturedAt'],
            'deviceId': device,
            'latitude': input['latitude'],
            'longitude': input['longitude'],
            'accuracyM': input['accuracyMeters'],
            'payload': {
              'siteId': input['siteId'],
              'isMocked': input['isMocked'],
            },
          },
        ],
      },
      key: key,
      etag: etag,
    );
  }
}
