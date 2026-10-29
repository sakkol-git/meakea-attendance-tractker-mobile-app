import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/features/notifications/data/repository.dart';

class PreferenceSource implements DataSource {
  @override
  final String mode;
  final requests = <DataRequest>[];
  String? etag = '"opaque-settings-a"';
  bool stale = false;
  PreferenceSource({this.mode = 'remote'});
  @override
  Future<DataResponse> send(DataRequest request) async {
    requests.add(request);
    if (request.method == 'PUT' && stale) {
      throw const DataFailure(412, 'STALE_VERSION', 'Review current settings.');
    }
    return DataResponse(
      200,
      mode == 'local'
          ? {'attendance': true, 'announcements': false, 'approvals': true}
          : {'email': false, 'inApp': true, 'reminders': false, 'version': 3},
      etag: etag,
    );
  }

  @override
  void close() {}
}

void main() {
  test('Given remote settings, toggling sends provider fields with the reviewed opaque ETag', () async {
    final source = PreferenceSource();
    final client = ClientData.forTest(source);
    addTearDown(client.close);
    final repository = NotificationsDataRepository(client);
    final settings = await repository.preferences();
    expect(settings.values, {
      'email': false,
      'inApp': true,
      'reminders': false,
    });
    await repository.savePreferences(settings.withValue('reminders', true));
    expect(source.requests.last.ifMatch, '"opaque-settings-a"');
    expect(source.requests.last.body, {
      'email': false,
      'inApp': true,
      'reminders': true,
    });
  });
  test(
    'Given no remote ETag, saving fails before sending a mutation',
    () async {
      final source = PreferenceSource()..etag = null;
      final client = ClientData.forTest(source);
      addTearDown(client.close);
      final repository = NotificationsDataRepository(client);
      final settings = await repository.preferences();
      await expectLater(
        repository.savePreferences(settings),
        throwsA(isA<DataFailure>().having((e) => e.status, 'status', 428)),
      );
      expect(source.requests.length, 1);
    },
  );
  test('Given stale settings, the client reports 412 without fetching a newer ETag and replaying', () async {
    final source = PreferenceSource();
    final client = ClientData.forTest(source);
    addTearDown(client.close);
    final repository = NotificationsDataRepository(client);
    final settings = await repository.preferences();
    source.stale = true;
    await expectLater(
      repository.savePreferences(settings),
      throwsA(isA<DataFailure>().having((e) => e.status, 'status', 412)),
    );
    expect(source.requests.map((r) => r.method), ['GET', 'PUT']);
  });
  test(
    'Given demo settings, the existing demo categories remain intact',
    () async {
      final source = PreferenceSource(mode: 'local')..etag = null;
      final client = ClientData.forTest(source);
      addTearDown(client.close);
      final repository = NotificationsDataRepository(client);
      final settings = await repository.preferences();
      await repository.savePreferences(settings.withValue('attendance', false));
      expect(source.requests.last.body, {
        'attendance': false,
        'announcements': false,
        'approvals': true,
      });
    },
  );
}
