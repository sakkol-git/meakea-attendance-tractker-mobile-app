import 'package:hrflow_mobile/core/protocol.dart';

import 'mappers.dart';

import 'package:hrflow_mobile/features/notifications/domain/models.dart';
import 'package:hrflow_mobile/core/data/resource_repository.dart';

mixin NotificationsMethods on ResourceRepository {
  Future<List<InboxMessage>> inbox() async =>
      (await collection('/notifications'))
          .map(InboxMessageMapper.fromJson)
          .toList();
  Future<void> markRead(String? id) => command(
    id == null ? '/notifications/read-all' : '/notifications/$id/read',
  ).then((_) {});
  Future<void> savePreferences(JsonMap values) async {
    await client.request(
      DataRequest('PUT', '/notifications/preferences', body: values),
    );
  }
}
