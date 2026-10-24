import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/data/json.dart';

import 'mappers.dart';

import 'package:hrflow_mobile/shared/domain/workflow.dart';
import 'package:hrflow_mobile/core/data/resource_repository.dart';

mixin WorkflowsMethods on ResourceRepository {
  Future<JsonMap?> readFormDraft(String kind) async {
    final response = object(
      (await client.request(DataRequest('GET', '/form-drafts/$kind'))).data,
    );
    return response['payload'] == null ? null : object(response['payload']);
  }

  Future<void> saveFormDraft(String kind, JsonMap payload) async {
    await client.request(
      DataRequest('PUT', '/form-drafts/$kind', body: {'payload': payload}),
    );
  }

  Future<void> clearFormDraft(String kind) async {
    await client.request(DataRequest('DELETE', '/form-drafts/$kind'));
  }

  Future<void> updateDraft(
    WorkflowRecord record,
    String title,
    String reason,
  ) async {
    await client.request(
      DataRequest(
        'PATCH',
        '${pathFor(record.kind)}/${record.id}',
        ifMatch: record.etag,
        body: {'title': title, 'reason': reason, 'description': reason},
      ),
    );
  }

  String pathFor(String kind) => kind == 'leave'
      ? '/leave/requests'
      : kind == 'correction'
      ? '/attendance/corrections'
      : '/requests';
  Future<RecordPage> recordsPage(
    String kind, {
    bool pending = false,
    int page = 0,
    int size = 25,
    String search = '',
    String status = '',
    String sort = '',
    int minAgeDays = 0,
  }) async {
    final path =
        pathFor(kind) +
        (pending
            ? '/pending'
            : kind == 'correction'
            ? ''
            : '/me');
    final result = await client.request(
      DataRequest(
        'GET',
        path,
        query: {
          'page': '$page',
          'size': '$size',
          if (search.isNotEmpty) 'search': search,
          if (status.isNotEmpty) 'status': status,
          if (sort.isNotEmpty) 'sort': sort,
          if (minAgeDays > 0) 'minAgeDays': '$minAgeDays',
        },
      ),
    );
    final data = object(result.data), rows = items(result.data);
    final total = data['total'];
    if (total is! int || total < 0) {
      throw const DataFailure(
        0,
        'CONTRACT_MISMATCH',
        'The API returned invalid pagination metadata.',
      );
    }
    return RecordPage(
      rows.map((r) => WorkflowRecordMapper.fromJson(r, kind)).toList(),
      total,
      page,
      size,
    );
  }

  Future<List<WorkflowRecord>> records(
    String kind, {
    bool pending = false,
  }) async {
    final path =
        pathFor(kind) +
        (pending
            ? '/pending'
            : kind == 'correction'
            ? ''
            : '/me');
    return (await collection(path))
        .map((r) => WorkflowRecordMapper.fromJson(r, kind))
        .toList();
  }

  Future<WorkflowRecord> detail(String kind, String id) async {
    final response = await client.request(
      DataRequest('GET', '${pathFor(kind)}/$id'),
    );
    return WorkflowRecordMapper.fromJson(
      object(response.data),
      kind,
      etag: response.etag,
    );
  }

  Future<WorkflowRecord> _record(
    Future<DataResponse> pending,
    String kind,
  ) async {
    final result = await pending;
    return WorkflowRecordMapper.fromJson(
      object(result.data),
      kind,
      etag: result.etag,
    );
  }

  Future<WorkflowRecord> create(String kind, JsonMap body, String key) =>
      _record(command(pathFor(kind), body: body, key: key), kind);
  Future<WorkflowRecord> decide(
    WorkflowRecord record,
    String action,
    String note,
    String key,
  ) => _record(
    command(
      '${pathFor(record.kind)}/${record.id}/$action',
      etag: record.etag,
      key: key,
      body: {'note': note, 'reason': note},
    ),
    record.kind,
  );
}
