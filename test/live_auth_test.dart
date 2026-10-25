import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/data/storage.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';

const password = String.fromEnvironment('LIVE_AUTH_PASSWORD');
const baseUrl = String.fromEnvironment(
  'LIVE_AUTH_BASE_URL',
  defaultValue: 'http://localhost:8080/api/v1',
);

void main() {
  test(
    'native session uses the live gateway',
    () async {
      final client = await ClientData.create(
        mode: 'remote',
        apiBaseUrl: baseUrl,
        secrets: MemorySecrets(),
      );
      addTearDown(client.close);
      final profile = await client.login(
        tenant: 'demo',
        email: 'owner@example.test',
        password: password,
      );
      expect(profile.name, 'Local Owner');
      expect(profile.tenantId, isNotEmpty);
      expect((await client.restoreSession())?.tenantId, profile.tenantId);
      await client.logout();
      expect(await client.restoreSession(), isNull);
    },
    skip: password.isEmpty
        ? 'Set LIVE_AUTH_PASSWORD for the local gateway'
        : false,
  );
}
