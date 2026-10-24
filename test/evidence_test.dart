import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/demo/local_service.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/attendance/data/repository.dart';
import 'package:hrflow_mobile/features/attendance/domain/evidence.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/features/notifications/application/push.dart';

void main() {
  test('reviewed transition uses stable batch identity and does not persist raw coordinates in demo', () async {
    final source = LocalDataSource(
      jsonDecode(File('assets/data/demo-seed.json').readAsStringSync())
          as JsonMap,
      populate: true,
      now: () => DateTime.utc(2026, 10, 23, 3),
    );
    final repository = AttendanceDataRepository(ClientData.forTest(source));
    final observation = AttendanceObservation(
      11.5564,
      104.9282,
      15,
      DateTime.utc(2026, 10, 23, 3),
    );
    expect(
      supportsGeofenceTransition(
        observation,
        latitude: 11.5564,
        longitude: 104.9282,
        radius: 200,
        entering: true,
      ),
      true,
    );
    expect(
      supportsGeofenceTransition(
        observation,
        latitude: 11.5564,
        longitude: 104.9282,
        radius: 200,
        entering: false,
      ),
      false,
    );
    final key = commandKey(),
        input = {
          ...observation.toInput(),
          'siteId': 'site-headquarters',
          'kind': 'GEOFENCE_ENTER',
        };
    await repository.changeCase('attendance.capture', null, input, key: key);
    await repository.changeCase('attendance.capture', null, input, key: key);
    final evidence = await repository.cases('attendance.evidence');
    expect(evidence, hasLength(1));
    expect(evidence.single.values['kind'], 'GEOFENCE_ENTER');
    expect(evidence.single.values.containsKey('latitude'), false);
    expect(evidence.single.values.containsKey('longitude'), false);
    expect((source.snapshot()['sessions'] as List), hasLength(4));
  });
  test(
    'notification links accept only known record types and safe identifiers',
    () {
      expect(
        notificationRecordPath({'kind': 'leave', 'recordId': 'leave-a'}),
        '/record/leave/leave-a',
      );
      expect(
        notificationRecordPath({
          'kind': 'https://external.example',
          'recordId': 'leave-a',
        }),
        isNull,
      );
      expect(
        notificationRecordPath({'kind': 'leave', 'recordId': '../security'}),
        isNull,
      );
    },
  );
}
