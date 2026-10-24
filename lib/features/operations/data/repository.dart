import '../../../core/data/case_repository.dart';
import '../../../core/data/resource_repository.dart';
import '../domain/repository.dart';

class OperationsDataRepository extends ResourceRepository
    with CaseMethods
    implements OperationsRepository {
  OperationsDataRepository(super.client);
  @override
  Map<String, CaseRoute> get caseRoutes => const {
    'operations.readiness': CaseRoute('/operations/workflow-status'),
  };
}
