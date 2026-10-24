import 'dart:convert';

import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/data/json.dart';

import 'mappers.dart';

import 'package:hrflow_mobile/features/attendance/domain/models.dart';
import 'package:hrflow_mobile/core/data/resource_repository.dart';

mixin AttendanceMethods on ResourceRepository {
  Future<AttendanceDay> today() async {
    final day = object(await get('/attendance/today'));
    final values = day['sessions'];
    if (values is! List) {
      throw const DataFailure(
        0,
        'CONTRACT_MISMATCH',
        'Attendance sessions are missing.',
      );
    }
    return AttendanceDay(
      day['workDate'] as String? ?? requiredText(day, 'date'),
      values.map((v) => WorkSessionMapper.fromJson(object(v))).toList(),
      (day['shift'] as Map?)?['name'] as String?,
    );
  }

  Future<List<WorkSession>> sessions({bool team = false}) async =>
      (await collection(team ? '/attendance/team' : '/attendance/me'))
          .map(WorkSessionMapper.fromJson)
          .toList();
  Future<void> clock({WorkSession? open, required String key}) async {
    final workspace = client.workspaceRevision;
    final storageKey = '${client.namespace}.clock.$key';
    final saved = await client.secrets.read(storageKey);
    late DataRequest request;
    if (saved != null) {
      final value = object(jsonDecode(saved));
      request = DataRequest(
        'POST',
        requiredText(value, 'path'),
        body: object(value['body']),
        ifMatch: value['etag'] as String?,
        idempotencyKey: key,
      );
    } else {
      final device = await client.secrets.read('hrflow.device') ?? commandKey();
      await client.secrets.write('hrflow.device', device);
      request = DataRequest(
        'POST',
        open == null ? '/attendance/check-in' : '/attendance/check-out',
        ifMatch: open?.etag,
        idempotencyKey: key,
        body: {
          'deviceId': device,
          'occurredAt': DateTime.now().toUtc().toIso8601String(),
          if (open != null) 'sessionId': open.id,
          if (open == null) 'source': 'TAP',
        },
      );
      await client.secrets.write(
        storageKey,
        jsonEncode({
          'path': request.path,
          'etag': request.ifMatch,
          'body': request.body,
        }),
      );
    }
    requireWorkspace(workspace);
    await client.request(request);
    await client.secrets.remove(storageKey);
  }
}
