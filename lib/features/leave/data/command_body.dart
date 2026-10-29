import 'package:hrflow_mobile/core/data/json.dart';
import 'package:hrflow_mobile/core/data/resource_repository.dart';
import 'package:hrflow_mobile/core/protocol.dart';

/// The form selects a catalog identity; the owner accepts its current type code.
Future<JsonMap> leaveCommandBody(
  ResourceRepository repository,
  JsonMap body,
) async {
  if (repository.client.isLocal) return body;
  final selection = body['leaveTypeId'] ?? body['type'];
  final types = await repository.collection('/leave/types');
  final type = types
      .where((row) => row['id'] == selection || row['code'] == selection)
      .firstOrNull;
  if (type == null) {
    throw const DataFailure(
      422,
      'LEAVE_TYPE_UNAVAILABLE',
      'Choose an available leave type and try again.',
    );
  }
  return {...body, 'type': requiredText(type, 'code')}..remove('leaveTypeId');
}
