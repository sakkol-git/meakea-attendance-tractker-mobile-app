import 'package:hrflow_mobile/features/notifications/application/push.dart';
import 'package:hrflow_mobile/features/notifications/data/push_device.dart';
import 'package:hrflow_mobile/features/attendance/application/evidence.dart';
import 'package:hrflow_mobile/features/attendance/data/location_capture.dart';
import 'package:hrflow_mobile/features/operations/application/providers.dart';
import 'package:hrflow_mobile/features/operations/data/repository.dart';
import 'package:hrflow_mobile/core/data/case_repository.dart';
import 'package:hrflow_mobile/features/identity/data/case_routes.dart';
import 'package:hrflow_mobile/features/attendance/data/case_routes.dart';
import 'package:hrflow_mobile/features/leave/data/case_routes.dart';
import 'package:hrflow_mobile/features/requests/data/case_routes.dart';
import 'package:hrflow_mobile/features/notifications/data/case_routes.dart';
import 'package:hrflow_mobile/features/reporting/data/case_routes.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:hrflow_mobile/features/requests/domain/repository.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/data/resource_repository.dart';
import 'package:hrflow_mobile/features/identity/data/methods.dart';
import 'package:hrflow_mobile/features/attendance/data/methods.dart';
import 'package:hrflow_mobile/features/leave/data/methods.dart';
import 'package:hrflow_mobile/features/notifications/data/methods.dart';
import 'package:hrflow_mobile/features/workflows/data/methods.dart';
import 'package:hrflow_mobile/features/attachments/data/methods.dart';
import 'package:hrflow_mobile/features/reporting/data/methods.dart';
import 'package:hrflow_mobile/features/identity/domain/repository.dart';
import 'package:hrflow_mobile/features/attendance/domain/repository.dart';
import 'package:hrflow_mobile/features/leave/domain/repository.dart';
import 'package:hrflow_mobile/features/notifications/domain/repository.dart';
import 'package:hrflow_mobile/features/reporting/domain/repository.dart';

abstract interface class WorkspaceRepository
    implements
        IdentityRepository,
        AttendanceRepository,
        LeaveRepository,
        RequestsRepository,
        NotificationsRepository,
        ReportingRepository {}

class HrRepository extends ResourceRepository
    with
        CaseMethods,
        WorkflowsMethods,
        AttachmentsMethods,
        IdentityMethods,
        AttendanceMethods,
        LeaveMethods,
        NotificationsMethods,
        ReportingMethods
    implements WorkspaceRepository {
  @override
  Map<String, CaseRoute> get caseRoutes => {
    ...identityCaseRoutes,
    ...attendanceCaseRoutes,
    ...leaveCaseRoutes,
    ...requestsCaseRoutes,
    ...notificationsCaseRoutes,
    ...reportingCaseRoutes,
  };

  HrRepository(super.client);
}

List<Override> testRepositoryOverrides(WorkspaceRepository repository) => [
  pushDeviceProvider.overrideWithValue(DemoPushDevice()),
  locationCaptureProvider.overrideWithValue(DemoLocationCapture()),
  if (repository is HrRepository)
    operationsRepositoryProvider.overrideWithValue(
      OperationsDataRepository(repository.client),
    ),
  identityRepositoryProvider.overrideWithValue(repository),
  attendanceRepositoryProvider.overrideWithValue(repository),
  leaveRepositoryProvider.overrideWithValue(repository),
  requestsRepositoryProvider.overrideWithValue(repository),
  notificationsRepositoryProvider.overrideWithValue(repository),
  reportingRepositoryProvider.overrideWithValue(repository),
];
