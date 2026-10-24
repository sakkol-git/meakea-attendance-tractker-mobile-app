import 'case_routes.dart';

import 'package:hrflow_mobile/core/data/case_repository.dart';
import 'package:hrflow_mobile/core/data/resource_repository.dart';

import '../domain/repository.dart';

import 'package:hrflow_mobile/features/attachments/data/methods.dart';
import 'package:hrflow_mobile/features/reporting/data/methods.dart';

class ReportingDataRepository extends ResourceRepository
    with CaseMethods, AttachmentsMethods, ReportingMethods
    implements ReportingRepository {
  @override
  Map<String, CaseRoute> get caseRoutes => reportingCaseRoutes;

  ReportingDataRepository(super.client);
}
