import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/core/data/storage.dart';

class AuthServer implements DataSource {
  @override
  String get mode => 'remote';
  int refreshes = 0;
  bool rotated = false, denyRefresh = false;
  Completer<void>? gate;
  final requests = <DataRequest>[];
  @override
  Future<DataResponse> send(DataRequest r) async {
    requests.add(r);
    if (r.path == '/auth/refresh') {
      refreshes++;
      if (gate != null) await gate!.future;
      if (denyRefresh) {
        throw const DataFailure(401, 'REFRESH_REVOKED', 'Sign in again');
      }
      rotated = true;
      return const DataResponse(200, {
        'accessToken': 'new-access',
        'refreshToken': 'new-refresh',
      });
    }
    if (r.path == '/auth/logout') return const DataResponse(204, null);
    if (!rotated) throw const DataFailure(401, 'EXPIRED', 'Expired');
    return const DataResponse(200, {'items': []});
  }

  @override
  void close() {}
}

void main() {
  test(
    'a replay response is discarded if the account changes during the replay',
    () async {
      final server = ReplayRaceServer();
      final secrets = MemorySecrets();
      await secrets.write(
        'test.tokens',
        jsonEncode({'accessToken': 'old', 'refreshToken': 'old-refresh'}),
      );
      final client = ClientData.forTest(server, store: secrets)
        ..setAccessToken('old');
      final pending = client.request(
        DataRequest(
          'POST',
          '/requests',
          body: {'title': 'Old account'},
          idempotencyKey: commandKey(),
        ),
      );
      final rejected = expectLater(
        pending,
        throwsA(
          isA<DataFailure>().having((e) => e.code, 'code', 'SESSION_CHANGED'),
        ),
      );
      await server.replayed.future;
      await client.login(
        tenant: 'other',
        email: 'other@example.test',
        password: 'fixture',
      );
      server.gate.complete(
        const DataResponse(201, {'id': 'old-private-record'}),
      );
      await rejected;
      expect(server.commands, 2);
      expect(
        jsonDecode((await secrets.read('test.tokens'))!)['accessToken'],
        'other-access',
      );
      client.close();
    },
  );
  test('a late profile response from an earlier login cannot erase newer credentials', () async {
    final server = ProfileRaceServer();
    final secrets = MemorySecrets();
    final client = ClientData.forTest(server, store: secrets);
    final first = client.login(
      tenant: 'first',
      email: 'first@example.test',
      password: 'fixture',
    );
    final rejected = expectLater(
      first,
      throwsA(
        isA<DataFailure>().having((e) => e.code, 'code', 'SESSION_CHANGED'),
      ),
    );
    await server.profileRequested.future;
    final second = await client.login(
      tenant: 'other',
      email: 'other@example.test',
      password: 'fixture',
    );
    server.firstProfile.complete(
      const DataResponse(200, {
        'tenantId': 'first',
        'employeeId': 'first',
        'roles': ['EMPLOYEE'],
      }),
    );
    await rejected;
    expect(second.tenantId, 'other');
    expect(
      jsonDecode((await secrets.read('test.tokens'))!)['accessToken'],
      'other-access',
    );
    client.close();
  });
  test(
    'late logout completion cannot erase a newer signed-in account',
    () async {
      final server = LogoutRaceServer();
      final secrets = MemorySecrets();
      await secrets.write(
        'test.tokens',
        jsonEncode({
          'accessToken': 'old-access',
          'refreshToken': 'old-refresh',
        }),
      );
      final client = ClientData.forTest(server, store: secrets)
        ..setAccessToken('old-access');
      final logout = client.logout();
      await Future<void>.delayed(Duration.zero);
      expect(server.logoutRefresh, 'old-refresh');
      await client.login(
        tenant: 'other',
        email: 'other@example.test',
        password: 'fixture',
      );
      server.logoutGate.complete(const DataResponse(204, null));
      await logout;
      expect(
        jsonDecode((await secrets.read('test.tokens'))!)['accessToken'],
        'other-access',
      );
      client.close();
    },
  );
  for (final unauthorized in [true, false]) {
    test(
      'old-account ${unauthorized ? '401' : 'success'} cannot replay or publish after another login',
      () async {
        final server = AccountSwitchServer();
        final secrets = MemorySecrets();
        final client = ClientData.forTest(server, store: secrets)
          ..setAccessToken('old');
        final pending = client.request(
          DataRequest(
            'POST',
            '/requests',
            body: {'title': 'Old account'},
            idempotencyKey: commandKey(),
          ),
        );
        final rejected = expectLater(
          pending,
          throwsA(
            isA<DataFailure>().having((e) => e.code, 'code', 'SESSION_CHANGED'),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await client.login(
          tenant: 'other',
          email: 'other@example.test',
          password: 'fixture',
        );
        if (unauthorized) {
          server.gate.completeError(
            const DataFailure(401, 'EXPIRED', 'Old session expired'),
          );
        } else {
          server.gate.complete(
            const DataResponse(201, {'id': 'private-old-account-record'}),
          );
        }
        await rejected;
        expect(server.commands, 1);
        expect(
          jsonDecode((await secrets.read('test.tokens'))!)['accessToken'],
          'other-access',
        );
        client.close();
      },
    );
  }

  test('parallel unauthorized requests serialize refresh and replay exact command keys', () async {
    final server = AuthServer()..gate = Completer<void>();
    final secrets = MemorySecrets();
    await secrets.write(
      'test.tokens',
      jsonEncode({'accessToken': 'old', 'refreshToken': 'refresh'}),
    );
    final client = ClientData.forTest(server, store: secrets)
      ..setAccessToken('old');
    final key = commandKey();
    final command = DataRequest(
      'POST',
      '/requests',
      body: {'title': 'Synthetic'},
      idempotencyKey: key,
    );
    final a = client.request(command),
        b = client.request(const DataRequest('GET', '/employees'));
    await Future<void>.delayed(Duration.zero);
    expect(server.refreshes, 1);
    server.gate!.complete();
    await Future.wait([a, b]);
    expect(server.refreshes, 1);
    final commands = server.requests
        .where((r) => r.path == '/requests')
        .toList();
    expect(commands, hasLength(2));
    expect(identical(commands.first, commands.last), true);
    expect(commands.last.idempotencyKey, key);
    expect(
      jsonDecode((await secrets.read('test.tokens'))!)['refreshToken'],
      'new-refresh',
    );
  });
  test('revoked refresh clears stored session and never loops', () async {
    final server = AuthServer()..denyRefresh = true;
    final secrets = MemorySecrets();
    await secrets.write(
      'test.tokens',
      jsonEncode({'accessToken': 'old', 'refreshToken': 'refresh'}),
    );
    final client = ClientData.forTest(server, store: secrets)
      ..setAccessToken('old');
    final expired = expectLater(client.sessionExpired, emits(null));
    await expectLater(
      client.request(const DataRequest('GET', '/employees')),
      throwsA(isA<DataFailure>()),
    );
    expect(server.refreshes, 1);
    expect(await secrets.read('test.tokens'), isNull);
    await expired;
  });
  test(
    'logout while refresh is in flight cannot restore credentials',
    () async {
      final server = AuthServer()..gate = Completer<void>();
      final secrets = MemorySecrets();
      await secrets.write(
        'test.tokens',
        jsonEncode({'accessToken': 'old', 'refreshToken': 'refresh'}),
      );
      final client = ClientData.forTest(server, store: secrets)
        ..setAccessToken('old');
      final request = client.request(const DataRequest('GET', '/employees'));
      await Future<void>.delayed(Duration.zero);
      await client.logout();
      server.gate!.complete();
      await expectLater(request, throwsA(isA<DataFailure>()));
      expect(await secrets.read('test.tokens'), isNull);
    },
  );
}

class AccountSwitchServer implements DataSource {
  @override
  String get mode => 'remote';
  final gate = Completer<DataResponse>();
  int commands = 0;
  @override
  Future<DataResponse> send(DataRequest request) async {
    if (request.path == '/requests') {
      commands++;
      return gate.future;
    }
    if (request.path == '/auth/login') {
      return const DataResponse(200, {
        'accessToken': 'other-access',
        'refreshToken': 'other-refresh',
      });
    }
    if (request.path == '/auth/me') {
      return const DataResponse(200, {
        'tenantId': 'other-tenant',
        'employeeId': 'other-employee',
        'roles': ['EMPLOYEE'],
        'name': 'Other employee',
      });
    }
    throw StateError('Unexpected route: ${request.path}');
  }

  @override
  void close() {}
}

class LogoutRaceServer extends AccountSwitchServer {
  final logoutGate = Completer<DataResponse>();
  String? logoutRefresh;
  @override
  Future<DataResponse> send(DataRequest request) {
    if (request.path == '/auth/logout') {
      logoutRefresh = request.body?['refreshToken'] as String?;
      return logoutGate.future;
    }
    return super.send(request);
  }
}

class ReplayRaceServer extends AccountSwitchServer {
  final replayed = Completer<void>();
  @override
  Future<DataResponse> send(DataRequest request) async {
    if (request.path == '/auth/refresh') {
      return const DataResponse(200, {
        'accessToken': 'rotated',
        'refreshToken': 'rotated-refresh',
      });
    }
    if (request.path == '/requests') {
      commands++;
      if (commands == 1) throw const DataFailure(401, 'EXPIRED', 'Expired');
      replayed.complete();
      return gate.future;
    }
    return super.send(request);
  }
}

class ProfileRaceServer implements DataSource {
  @override
  String get mode => 'remote';
  final profileRequested = Completer<void>();
  final firstProfile = Completer<DataResponse>();
  String tenant = 'first';
  @override
  Future<DataResponse> send(DataRequest request) async {
    if (request.path == '/auth/login') {
      tenant = request.body!['tenantSlug'] as String;
      return DataResponse(200, {
        'accessToken': '$tenant-access',
        'refreshToken': '$tenant-refresh',
      });
    }
    if (request.path == '/auth/me' && tenant == 'first') {
      profileRequested.complete();
      return firstProfile.future;
    }
    return DataResponse(200, {
      'tenantId': tenant,
      'employeeId': tenant,
      'roles': ['EMPLOYEE'],
    });
  }

  @override
  void close() {}
}
