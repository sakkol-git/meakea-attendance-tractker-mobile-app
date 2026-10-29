import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/features/notifications/domain/notice_route.dart';

void main() {
  test('native inbox and push share validated domain routes', () {
    expect(
      notificationRecordPath({'kind': 'request', 'recordId': 'request-a'}),
      '/record/request/request-a',
    );
    expect(
      notificationRecordPath({'kind': 'leave', 'recordId': 'leave-a'}),
      '/record/leave/leave-a',
    );
    expect(
      notificationRecordPath({
        'kind': 'correction',
        'recordId': 'correction-a',
      }),
      '/record/correction/correction-a',
    );
    expect(
      notificationRecordPath({'kind': 'attendance', 'recordId': 'session-a'}),
      '/activity',
    );
    for (final value in [
      {'kind': 'unknown', 'recordId': 'id'},
      {'kind': 'request', 'recordId': '../foreign'},
      {'kind': 'request'},
      {'to': ''},
    ]) {
      expect(notificationRecordPath(value), isNull);
    }
  });
}
