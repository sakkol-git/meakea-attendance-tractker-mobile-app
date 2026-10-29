import 'package:hrflow_mobile/shared/domain/cases.dart';
import 'package:hrflow_mobile/features/notifications/domain/models.dart';
import 'package:hrflow_mobile/shared/domain/resource_gateway.dart';

abstract interface class NotificationsRepository
    implements CaseGateway, ResourceGateway {
  Future<List<InboxMessage>> inbox();
  Future<void> markRead(String? id);
  Future<NotificationPreferences> preferences();
  Future<void> savePreferences(NotificationPreferences preferences);
}
