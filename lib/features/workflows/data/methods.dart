import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/data/json.dart';

import 'mappers.dart';

import 'package:hrflow_mobile/shared/domain/workflow.dart';
import 'package:hrflow_mobile/core/data/resource_repository.dart';
import 'package:hrflow_mobile/features/leave/data/command_body.dart';

mixin WorkflowsMethods on ResourceRepository {
  // The current backend has no account-scoped form-draft API.
  bool get supportsFormDrafts => client.isLocal;
  void _requireFormDrafts() {
    if (!supportsFormDrafts) {
      throw const DataFailure(
        501,
        'DRAFT_RECOVERY_UNAVAILABLE',
        'Unsaved form recovery is unavailable for this workspace.',
      );
    }
  }

  Future<JsonMap?> readFormDraft(String kind) async {
    _requireFormDrafts();
    final response = object(
      (await client.request(DataRequest('GET', '/form-drafts/$kind'))).data,
    );
    return response['payload'] == null ? null : object(response['payload']);
  }

  Future<void> saveFormDraft(String kind, JsonMap payload) async {
    _requireFormDrafts();
    await client.request(
      DataRequest('PUT', '/form-drafts/$kind', body: {'payload': payload}),
    );
  }

  Future<void> clearFormDraft(String kind) async {
    _requireFormDrafts();
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

  String listPathFor(String kind, bool pending) {
    if (!pending) {
      return kind == 'correction' ? pathFor(kind) : '${pathFor(kind)}/me';
    }
    if (client.isLocal) return '${pathFor(kind)}/pending';
    if (kind == 'request') return '/requests/inbox';
    return kind == 'correction'
        ? '/attendance/corrections'
        : '${pathFor(kind)}/pending';
  }

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
    final path = listPathFor(kind, pending);
    final result = await client.request(
      DataRequest(
        'GET',
        path,
        query: {
          'page': '$page',
          'size': '$size',
          if (search.isNotEmpty) 'search': search,
          if (status.isNotEmpty || (pending && kind == 'correction'))
            'status': status.isEmpty ? 'PENDING' : status,
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
    final path = listPathFor(kind, pending);
    return (await collection(
      path,
      query: {if (pending && kind == 'correction') 'status': 'PENDING'},
    )).map((r) => WorkflowRecordMapper.fromJson(r, kind)).toList();
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

  Future<WorkflowRecord> create(String kind, JsonMap body, String key) async =>
      _record(
        command(pathFor(kind), body: await _commandBody(kind, body), key: key),
        kind,
      );

  Future<JsonMap> _commandBody(String kind, JsonMap body) async {
    if (client.isLocal) return body;
    switch (kind) {
      case 'leave':
        return leaveCommandBody(this, body);
      case 'correction':
        return {
          'date': body['date'] ?? body['workDate'],
          'proposedClockIn': body['proposedClockIn'] ?? body['newCheckIn'],
          'proposedClockOut': body['proposedClockOut'] ?? body['newCheckOut'],
          'reason': body['reason'],
          if (body['sessionId'] != null) 'sessionId': body['sessionId'],
        };
      default:
        return kind == 'request' ? _requestBody(body) : body;
    }
  }

  JsonMap _requestBody(JsonMap body) =>
      !client.isLocal && body['type'] != 'MATERIAL'
      ? {...body, 'quantity': body['quantity'] ?? 1}
      : body;

  @override
  Future<void> saveEntity(
    String path,
    JsonMap values, {
    JsonMap? existing,
    String? key,
  }) => super.saveEntity(
    path,
    path == '/requests' ? _requestBody(values) : values,
    existing: existing,
    key: key,
  );

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
