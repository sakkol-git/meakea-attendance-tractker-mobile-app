import 'package:hrflow_mobile/core/protocol.dart';

import 'json.dart';

import 'package:hrflow_mobile/core/data/api_client.dart';

abstract class ResourceRepository {
  final ApiClient client;
  ResourceRepository(this.client);
  void requireWorkspace(int revision) {
    if (revision != client.workspaceRevision) {
      throw const DataFailure(
        0,
        'SESSION_CHANGED',
        'Your account changed. Restart this action in the current workspace.',
      );
    }
  }

  Future<dynamic> get(String path) async =>
      (await client.request(DataRequest('GET', path))).data;
  Future<List<JsonMap>> collection(String path) async {
    if (client.isLocal) return items(await get(path));
    final rows = <JsonMap>[];
    const size = 100;
    for (var page = 0; page < 100; page++) {
      final response = await client.request(
        DataRequest('GET', path, query: {'page': '$page', 'size': '$size'}),
      );
      final body = object(response.data), batch = items(response.data);
      final total = requiredInt(body, 'total');
      rows.addAll(batch);
      if (rows.length >= total) return rows;
      if (batch.isEmpty) {
        throw const DataFailure(
          0,
          'CONTRACT_MISMATCH',
          'The API returned an incomplete page.',
        );
      }
    }
    throw const DataFailure(
      0,
      'COLLECTION_LIMIT',
      'This collection exceeds 10,000 records. Use a narrower server view.',
    );
  }

  Future<DataResponse> command(
    String path, {
    JsonMap? body,
    String? etag,
    String? key,
  }) => client.request(
    DataRequest(
      'POST',
      path,
      body: body,
      ifMatch: etag,
      idempotencyKey: key ?? commandKey(),
    ),
  );
  Future<void> saveEntity(
    String path,
    JsonMap values, {
    JsonMap? existing,
    String? key,
  }) async {
    if (existing == null) {
      await command(path, body: values, key: key);
    } else {
      await client.request(
        DataRequest(
          'PATCH',
          '$path/${existing['id']}',
          body: values,
          ifMatch: existing['etag'] as String? ?? '"${existing['version']}"',
        ),
      );
    }
  }

  Future<void> refresh() => client.clearCache();
}
