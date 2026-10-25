import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/app/configuration.dart';
import 'package:hrflow_mobile/core/protocol.dart';

void main() {
  test('release configuration refuses implicit local data', () {
    expect(
      () => validateClientConfiguration(
        release: true,
        dataSource: 'local',
        allowDemoRelease: false,
      ),
      throwsA(
        isA<DataFailure>().having(
          (failure) => failure.code,
          'code',
          'DEMO_RELEASE_BLOCKED',
        ),
      ),
    );
  });

  test('debug and explicit demo releases remain available', () {
    expect(
      () => validateClientConfiguration(
        release: false,
        dataSource: 'local',
        allowDemoRelease: false,
      ),
      returnsNormally,
    );
    expect(
      () => validateClientConfiguration(
        release: true,
        dataSource: 'local',
        allowDemoRelease: true,
      ),
      returnsNormally,
    );
    expect(
      () => validateClientConfiguration(
        release: true,
        dataSource: 'remote',
        allowDemoRelease: false,
        apiBaseUrl: 'https://hr.example.test/api/v1',
      ),
      returnsNormally,
    );
  });

  test('remote mode requires a safe versioned API URL', () {
    for (final url in [
      '',
      'http://hr.example.test/api/v1',
      'https://user:secret@hr.example.test/api/v1',
      'https://hr.example.test/api/v1?tenant=a',
      'https://hr.example.test/api',
    ]) {
      expect(
        () => validateClientConfiguration(
          release: false,
          dataSource: 'remote',
          allowDemoRelease: false,
          apiBaseUrl: url,
        ),
        throwsA(
          isA<DataFailure>().having(
            (failure) => failure.code,
            'code',
            'INVALID_API_URL',
          ),
        ),
        reason: url,
      );
    }
    validateClientConfiguration(
      release: false,
      dataSource: 'remote',
      allowDemoRelease: false,
      apiBaseUrl: 'http://127.0.0.1:8080/api/v1/',
    );
  });
}
