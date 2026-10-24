import 'case_routes.dart';

import 'package:hrflow_mobile/core/data/case_repository.dart';
import 'package:hrflow_mobile/core/data/resource_repository.dart';

import '../domain/repository.dart';

import 'package:hrflow_mobile/features/workflows/data/methods.dart';
import 'package:hrflow_mobile/features/attachments/data/methods.dart';
import 'package:hrflow_mobile/features/leave/data/methods.dart';

class LeaveDataRepository extends ResourceRepository
    with CaseMethods, WorkflowsMethods, AttachmentsMethods, LeaveMethods
    implements LeaveRepository {
  @override
  Map<String, CaseRoute> get caseRoutes => leaveCaseRoutes;

  LeaveDataRepository(super.client);
}
