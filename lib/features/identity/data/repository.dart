import 'case_routes.dart';

import 'package:hrflow_mobile/core/data/case_repository.dart';
import 'package:hrflow_mobile/core/data/resource_repository.dart';

import '../domain/repository.dart';

import 'package:hrflow_mobile/features/identity/data/methods.dart';

class IdentityDataRepository extends ResourceRepository
    with CaseMethods, IdentityMethods
    implements IdentityRepository {
  @override
  Map<String, CaseRoute> get caseRoutes => identityCaseRoutes;

  IdentityDataRepository(super.client);
}
