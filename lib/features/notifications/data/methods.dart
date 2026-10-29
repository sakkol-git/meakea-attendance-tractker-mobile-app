import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/data/json.dart';

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
  List<String> get _preferenceKeys => client.isLocal
      ? ['attendance', 'announcements', 'approvals']
      : ['email', 'inApp', 'reminders'];

  Future<NotificationPreferences> preferences() async {
    final response = await client.request(
      const DataRequest('GET', '/notifications/preferences'),
    );
    final data = object(response.data);
    final values = <String, bool>{};
    for (final key in _preferenceKeys) {
      if (data[key] is! bool) {
        throw const DataFailure(
          0,
          'CONTRACT_MISMATCH',
          'Notification settings are incomplete.',
        );
      }
      values[key] = data[key] as bool;
    }
    return NotificationPreferences(values, revisionToken: response.etag);
  }

  Future<void> savePreferences(NotificationPreferences preferences) async {
    if (!client.isLocal && (preferences.revisionToken?.isEmpty ?? true)) {
      throw const DataFailure(
        428,
        'VERSION_REQUIRED',
        'Refresh your settings before saving.',
      );
    }
    final values = preferences.values;
    if (values.length != _preferenceKeys.length ||
        !_preferenceKeys.every(values.containsKey)) {
      throw const DataFailure(
        422,
        'VALIDATION_ERROR',
        'Choose valid notification settings.',
      );
    }
    await client.request(
      DataRequest(
        'PUT',
        '/notifications/preferences',
        body: values,
        ifMatch: preferences.revisionToken,
      ),
    );
  }
}
