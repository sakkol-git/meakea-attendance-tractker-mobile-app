import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/widgets.dart';

void main() {
  test('workflow status labels use the shared client vocabulary', () {
    expect(statusLabel('PENDING'), 'Pending approval');
    expect(statusLabel('REVIEW_NEEDED'), 'Review needed');
    expect(statusLabel('CUSTOM_STATUS'), 'Custom status');
  });
}
