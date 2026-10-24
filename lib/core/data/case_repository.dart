import '../protocol.dart';
import '../../shared/domain/cases.dart';
import 'resource_repository.dart';
import 'json.dart';

class CaseRoute {
  final String method, path;
  final bool versioned, single;
  const CaseRoute(
    this.path, {
    this.method = 'GET',
    this.versioned = false,
    this.single = false,
  });
}

mixin CaseMethods on ResourceRepository implements CaseGateway {
  Map<String, CaseRoute> get caseRoutes;
  @override
  Future<List<CaseRecord>> cases(
    String collection, {
    Map<String, String> filters = const {},
  }) async {
    final route = caseRoutes[collection];
    if (route == null || route.method != 'GET') {
      throw const DataFailure(404, 'UNKNOWN_VIEW', 'This view is unavailable.');
    }
    final response = await client.request(
      DataRequest('GET', route.path, query: filters),
    );
    final body = object(response.data);
    final rows = route.single ? [body] : items(body);
    return rows
        .map(
          (row) => CaseRecord(
            id: requiredText(row, 'id'),
            title: text(
              row,
              'name',
              text(row, 'title', text(row, 'employeeName', 'Record')),
            ),
            status: text(row, 'status', 'ACTIVE'),
            version: row['version'] == null ? 1 : requiredInt(row, 'version'),
            revision:
                row['etag'] as String? ?? (route.single ? response.etag : null),
            values: freeze(row) as JsonMap,
          ),
        )
        .toList();
  }

  @override
  Future<JsonMap> changeCase(
    String action,
    String? id,
    JsonMap input, {
    required String key,
    String? etag,
  }) async {
    final route = caseRoutes[action];
    if (route == null || route.method == 'GET') {
      throw const DataFailure(
        404,
        'UNKNOWN_ACTION',
        'This action is unavailable.',
      );
    }
    if (route.path.contains('{id}') &&
        (id == null || !RegExp(r'^[a-z0-9-]+$').hasMatch(id))) {
      throw const DataFailure(422, 'INVALID_RECORD', 'Select a valid record.');
    }
    final response = await client.request(
      DataRequest(
        route.method,
        route.path.replaceAll('{id}', id ?? ''),
        body: input,
        idempotencyKey: route.method == 'POST' ? key : null,
        ifMatch: route.versioned ? etag : null,
      ),
    );
    return response.data == null ? <String, dynamic>{} : object(response.data);
  }
}
