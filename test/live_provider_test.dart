import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:hrflow_mobile/core/data/remote_source.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/features/requests/data/repository.dart';
import 'package:hrflow_mobile/features/attendance/data/repository.dart';
import 'package:hrflow_mobile/features/notifications/data/repository.dart';

// Only the disposable fixture maps /api/v1 to direct owner controller roots.
// This is actual provider HTTP; it does not prove gateway routing or login.
class DirectOwnerClient extends http.BaseClient {
  final http.Client upstream = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final uri = request.url.replace(
      path: request.url.path.replaceFirst('/api/v1', ''),
    );
    final forwarded = http.Request(request.method, uri)
      ..followRedirects = false
      ..headers.addAll(request.headers)
      ..bodyBytes = await request.finalize().toBytes();
    return upstream.send(forwarded);
  }

  @override
  void close() => upstream.close();
}

void main() {
  final env = Platform.environment;
  final ready =
      env['HRFLOW_REQUEST_BASE_URL'] != null &&
      env['HRFLOW_NOTIFICATION_BASE_URL'] != null &&
      env['HRFLOW_EMPLOYEE_TOKEN'] != null &&
      env['HRFLOW_FOREIGN_TOKEN'] != null;
  ClientData client(String base, String? token) {
    final root = Uri.parse(base);
    if (!['localhost', '127.0.0.1', '::1'].contains(root.host)) {
      throw StateError('Fixture must use loopback.');
    }
    final value = ClientData.forTest(
      RemoteDataSource(
        '${root.origin}/api/v1',
        () => token,
        client: DirectOwnerClient(),
      ),
    );
    addTearDown(value.close);
    return value;
  }

  Matcher status(int code) =>
      isA<DataFailure>().having((e) => e.status, 'status', code);
  test(
    'native consumers exercise actual request pages, reviewed draft, private evidence and tenant denial',
    () async {
      final employee = client(
        env['HRFLOW_REQUEST_BASE_URL']!,
        env['HRFLOW_EMPLOYEE_TOKEN'],
      );
      final repo = RequestsDataRepository(employee);
      final key = commandKey();
      final body = <String, dynamic>{
        'title': 'Synthetic native provider check',
        'type': 'GENERAL',
        'reason': 'Disposable integration evidence',
        'quantity': 1,
      };
      final record = await repo.create('request', body, key);
      final retry = await repo.create('request', body, key);
      expect(retry.id, record.id);
      await expectLater(
        repo.create('request', {...body, 'title': 'Changed payload'}, key),
        throwsA(status(409)),
      );
      expect(
        (await repo.recordsPage('request')).records
            .any((r) => r.id == record.id),
        isTrue,
      );
      final reviewed = await repo.detail('request', record.id);
      expect(reviewed.revisionToken, isNotNull);
      await repo.updateDraft(
        reviewed,
        'Reviewed native evidence',
        'Disposable integration evidence',
      );
      await expectLater(
        repo.updateDraft(
          reviewed,
          'Stale edit',
          'Disposable integration evidence',
        ),
        throwsA(status(412)),
      );
      final current = await repo.detail('request', record.id);
      final bytes = Uint8List.fromList(
        utf8.encode('%PDF-1.4\nSynthetic fixture\n%%EOF'),
      );
      await repo.attach(current, 'synthetic-native.pdf', bytes);
      final detail = await repo.detail('request', record.id);
      final files = (detail.fields['attachments'] as List).cast<Map>();
      expect(files, isNotEmpty);
      final file = Map<String, dynamic>.from(files.last);
      expect(await repo.download(detail, file), bytes);
      final materials = await repo.collection('/materials');
      if (materials.isEmpty) {
        throw StateError('Fixture requires an active same-tenant material.');
      }
      final materialId = materials.first['id'];
      final material = await repo.create('request', {
        'title': 'Synthetic native material',
        'type': 'MATERIAL',
        'reason': 'Disposable material evidence',
        'quantity': 2,
        'items': [
          {'materialId': materialId, 'quantity': 2},
        ],
      }, commandKey());
      final materialDetail = await repo.detail('request', material.id);
      expect(
        (materialDetail.fields['items'] as List).first['materialId'],
        materialId,
      );
      await repo.saveEntity(
        '/requests',
        {
          'title': 'Updated synthetic material',
          'type': 'MATERIAL',
          'reason': 'Disposable material evidence',
          'quantity': 3,
          'items': [
            {'materialId': materialId, 'quantity': 3},
          ],
        },
        existing: {
          'id': material.id,
          'version': materialDetail.version,
          'etag': materialDetail.etag,
        },
      );
      expect(
        ((await repo.detail('request', material.id)).fields['items'] as List)
            .first['quantity'],
        3,
      );
      for (final type in ['REMOTE_WORK', 'LATE_ARRIVAL', 'EARLY_LEAVE']) {
        final dates = <String, dynamic>{
          'startDate': '2026-11-02',
          'endDate': '2026-11-02',
          if (type != 'REMOTE_WORK') ...{
            'fromTime': '08:30',
            'toTime': '09:00',
          },
        };
        final typed = await repo.create('request', {
          'title': 'Synthetic $type',
          'type': type,
          'reason': 'Disposable date evidence',
          'quantity': 1,
          ...dates,
        }, commandKey());
        final value = await repo.detail('request', typed.id);
        for (final entry in dates.entries) {
          expect(value.fields[entry.key], entry.value);
        }
      }
      final attendanceClient = client(
        env['HRFLOW_ATTENDANCE_BASE_URL']!,
        env['HRFLOW_EMPLOYEE_TOKEN'],
      );
      final attendance = AttendanceDataRepository(attendanceClient);
      final correction = await attendance.create('correction', {
        'workDate': '2026-10-27',
        'newCheckIn': '2026-10-27T01:00:00Z',
        'newCheckOut': '2026-10-27T10:00:00Z',
        'reason': 'Synthetic correction evidence',
      }, commandKey());
      final ownCorrection = await attendance.detail(
        'correction',
        correction.id,
      );
      expect(ownCorrection.revisionToken, isNotNull);
      await expectLater(
        attendance.decide(ownCorrection, 'approve', '', commandKey()),
        throwsA(status(403)),
      );
      final reviewerClient = client(
        env['HRFLOW_ATTENDANCE_BASE_URL']!,
        env['HRFLOW_MANAGER_TOKEN'],
      );
      final reviewer = AttendanceDataRepository(reviewerClient);
      final reviewedCorrection = await reviewer.detail(
        'correction',
        correction.id,
      );
      expect(
        (await reviewer.recordsPage(
          'correction',
          pending: true,
        )).records.any((r) => r.id == correction.id),
        isTrue,
      );
      await expectLater(
        reviewerClient.request(
          DataRequest(
            'POST',
            '/attendance/corrections/${correction.id}/approve',
            ifMatch: '"stale"',
            idempotencyKey: commandKey(),
          ),
        ),
        throwsA(status(412)),
      );
      expect(
        (await reviewer.decide(
          reviewedCorrection,
          'approve',
          '',
          commandKey(),
        )).status,
        'APPROVED',
      );
      await expectLater(
        AttendanceDataRepository(
          client(
            env['HRFLOW_ATTENDANCE_BASE_URL']!,
            env['HRFLOW_FOREIGN_TOKEN'],
          ),
        ).detail('correction', correction.id),
        throwsA(status(404)),
      );
      final foreign = RequestsDataRepository(
        client(env['HRFLOW_REQUEST_BASE_URL']!, env['HRFLOW_FOREIGN_TOKEN']),
      );
      await expectLater(
        foreign.detail('request', record.id),
        throwsA(status(404)),
      );
      await expectLater(foreign.download(detail, file), throwsA(status(404)));
      await expectLater(
        RequestsDataRepository(client(env['HRFLOW_REQUEST_BASE_URL']!, null))
            .detail('request', record.id),
        throwsA(status(401)),
      );
      await repo.decide(detail, 'submit', '', commandKey());
      for (final role in ['MANAGER', 'HR']) {
        final token = env['HRFLOW_${role}_TOKEN'];
        if (token == null) {
          throw StateError(
            'Fixture lacks $role token; role coverage is incomplete.',
          );
        }
        await RequestsDataRepository(
          client(env['HRFLOW_REQUEST_BASE_URL']!, token),
        ).recordsPage('request', pending: true);
      }
      await expectLater(
        RequestsDataRepository(
          client(env['HRFLOW_REQUEST_BASE_URL']!, env['HRFLOW_OWNER_TOKEN']),
        ).recordsPage('request', pending: true),
        throwsA(status(403)),
      );
      await expectLater(
        repo.recordsPage('request', pending: true),
        throwsA(status(403)),
      );
    },
    skip: ready ? false : 'Requires disposable real-provider fixture URLs and synthetic role tokens.',
  );
  test(
    'native notification settings send exact ETag and preserve stale-write failure',
    () async {
      final repo = NotificationsDataRepository(
        client(
          env['HRFLOW_NOTIFICATION_BASE_URL']!,
          env['HRFLOW_EMPLOYEE_TOKEN'],
        ),
      );
      await repo.inbox();
      final settings = await repo.preferences();
      await repo.savePreferences(
        settings.withValue('reminders', !settings.values['reminders']!),
      );
      await expectLater(repo.savePreferences(settings), throwsA(status(412)));
    },
    skip: ready ? false : 'Requires disposable real-provider fixture URLs and synthetic role tokens.',
  );
}
