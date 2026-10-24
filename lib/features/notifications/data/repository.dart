import 'case_routes.dart';

import 'package:hrflow_mobile/core/data/case_repository.dart';
import 'package:hrflow_mobile/core/data/resource_repository.dart';

import '../domain/repository.dart';

import 'package:hrflow_mobile/features/notifications/data/methods.dart';

class NotificationsDataRepository extends ResourceRepository
    with CaseMethods, NotificationsMethods
    implements NotificationsRepository {
  @override
  Map<String, CaseRoute> get caseRoutes => notificationsCaseRoutes;

  NotificationsDataRepository(super.client);
}
