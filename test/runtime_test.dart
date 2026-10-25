import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/app/runtime.dart';
import 'package:hrflow_mobile/core/protocol.dart';

void main() {
  test('server failures expose a support reference consistently', () {
    expect(
      message(
        const DataFailure(
          503,
          'UNAVAILABLE',
          'Service unavailable',
          traceId: 'trace-123',
        ),
      ),
      'Service unavailable Reference: trace-123.',
    );
    expect(
      message(
        const DataFailure(
          403,
          'FORBIDDEN',
          'Internal detail',
          traceId: 'trace-456',
        ),
      ),
      'You do not have permission to perform this action. Reference: trace-456.',
    );
  });
}
