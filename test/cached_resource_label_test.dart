import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/presentation_format.dart';

void main() {
  test('saved-data notices describe user tasks without exposing routes or record IDs', () {
    expect(
      cachedResourceLabel('/attendance/sessions?employeeId=private-id'),
      'Attendance',
    );
    expect(cachedResourceLabel('/leave/me'), 'Leave');
    expect(cachedResourceLabel('/requests/private-id'), 'Requests');
    expect(cachedResourceLabel('/notifications'), 'Notifications');
    expect(cachedResourceLabel('/employees/private-id'), 'People');
    expect(cachedResourceLabel('/unknown/private-id'), 'Workspace information');
  });
}
