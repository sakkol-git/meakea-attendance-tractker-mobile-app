import 'package:hrflow_mobile/core/data/json.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/notifications/domain/models.dart';

abstract final class InboxMessageMapper {
  static InboxMessage fromJson(JsonMap j) => InboxMessage(
    requiredText(j, 'id'),
    requiredText(j, 'title'),
    j['body'] as String? ?? '',
    j['read'] as bool? ?? false,
    j['recordId'] as String?,
    j['kind'] as String?,
  );
}
