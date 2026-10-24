import 'package:hrflow_mobile/core/data/api_client.dart';

import 'dart:convert';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hrflow_mobile/features/identity/domain/models.dart';

import '../domain/session_gateway.dart';

import 'package:hrflow_mobile/core/data/cache/cached_source.dart';
import 'package:hrflow_mobile/core/data/cache/store.dart';

import 'mappers.dart';

import 'package:hrflow_mobile/core/data/json.dart';
import 'package:hrflow_mobile/core/demo/local_service.dart';
import 'package:hrflow_mobile/core/data/remote_source.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/data/storage.dart';
import 'package:hrflow_mobile/core/data/pending_commands.dart';

class ClientData implements SessionGateway, ApiClient {
  late final DataSource source;
  @override
  final SecretStore secrets;
  @override
  final String namespace;
  String? _accessToken;
  final _expired = StreamController<void>.broadcast();
  @override
  Stream<void> get sessionExpired => _expired.stream;
  Future<void>? _refreshing;
  int _generation = 0;
  int _workspaceGeneration = 0;
  @override
  int get workspaceRevision => _workspaceGeneration;
  Future<void> _credentials = Future.value();
  Future<void> _credentialOperation(Future<void> Function() task) {
    final result = _credentials.then((_) => task());
    _credentials = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  ClientData._(this.secrets, this.namespace);
  Future<void> _bindCommandAccount(Profile profile) async {
    final slot = '$namespace.pending.account';
    final identity = '${profile.tenantId}:${profile.id}';
    final previous = await secrets.read(slot);
    if (previous != null && previous != identity) {
      await PendingCommandKeys(secrets, namespace).clearAll();
    }
    await secrets.write(slot, identity);
  }

  static Future<ClientData> create({
    String mode = const String.fromEnvironment(
      'DATA_SOURCE',
      defaultValue: 'local',
    ),
    String apiBaseUrl = const String.fromEnvironment('API_BASE_URL'),
    SecretStore? secrets,
    bool persistDemo = true,
  }) async {
    final client = ClientData._(
      secrets ?? const DeviceSecrets(),
      'hrflow.session.$apiBaseUrl',
    );
    switch (mode) {
      case 'local':
        final seed = jsonDecode(
          await rootBundle.loadString('assets/data/demo-seed.json'),
        ) as JsonMap;
        final local = LocalDataSource(seed, populate: true);
        if (persistDemo) {
          final prefs = SharedPreferencesAsync();
          final saved = await prefs.getString('hrflow.demo.v2');
          if (saved != null) {
            try {
              local.restore(object(jsonDecode(saved)));
            } catch (_) {
              await prefs.remove('hrflow.demo.v2');
            }
          }
          local.onChanged = (snapshot) =>
              prefs.setString('hrflow.demo.v2', jsonEncode(snapshot));
        }
        client.source = local;
      case 'remote':
        CacheStore cache;
        try {
          cache = await EncryptedCacheStore.open(apiBaseUrl, client.secrets);
        } catch (_) {
          cache = MemoryCacheStore();
        }
        client.source = CachedDataSource(
          RemoteDataSource(apiBaseUrl, () => client._accessToken),
          cache,
        );
      default:
        throw const DataFailure(
          0,
          'INVALID_MODE',
          'Data mode must be local or remote.',
        );
    }
    return client;
  }

  /// Test composition keeps the same repository surface with injectable transport/storage.
  ClientData.forTest(DataSource dataSource, {SecretStore? store})
    : secrets = store ?? MemorySecrets(),
      namespace = 'test' {
    source = dataSource;
  }
  @override
  Future<void> clearCache() async {
    if (source is CachedDataSource) await (source as CachedDataSource).clear();
  }

  @override
  Stream<bool> get staleChanges => source is CachedDataSource
      ? (source as CachedDataSource).staleChanges
      : const Stream.empty();
  Stream<List<StaleResource>> get staleResources => source is CachedDataSource
      ? (source as CachedDataSource).staleResources
      : const Stream.empty();
  @override
  Future<void> resetDemo() async {
    if (source is! LocalDataSource) {
      throw const DataFailure(403, 'FORBIDDEN', 'Demo reset is unavailable.');
    }
    final demo = source as LocalDataSource;
    demo.reset();
    if (demo.onChanged != null) await demo.onChanged!(demo.snapshot());
  }

  @override
  bool get isLocal => source.mode == 'local';
  void setAccessToken(String? value) => _accessToken = value;
  void clearSession({bool invalidateWorkspace = true}) {
    _generation++;
    if (invalidateWorkspace) _workspaceGeneration++;
    _accessToken = null;
  }

  @override
  Future<Profile?> restoreSession() async {
    if (isLocal) return null; // Demo requires an explicit persona choice.
    final saved = await secrets.read('$namespace.tokens');
    if (saved == null) return null;
    final tokens = object(jsonDecode(saved));
    _accessToken = requiredText(tokens, 'accessToken');
    try {
      final raw = object(
        (await request(const DataRequest('GET', '/auth/me'))).data,
      );
      final profile = ProfileMapper.fromJson(raw);
      await _bindCommandAccount(profile);
      if (source is CachedDataSource) {
        await (source as CachedDataSource).bind(
          '$namespace:${raw['tenantId']}:${profile.id}:${profile.role}',
        );
      }
      return profile;
    } on DataFailure catch (e) {
      if (e.status == 401) {
        await _eraseSession();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<Profile> login({
    required String tenant,
    required String email,
    required String password,
  }) async {
    _workspaceGeneration++;
    final epoch = ++_generation;
    final result = await source.send(
      DataRequest(
        'POST',
        '/auth/login',
        body: {'tenantSlug': tenant, 'email': email, 'password': password},
      ),
    );
    if (epoch != _generation) {
      throw const DataFailure(401, 'SESSION_CHANGED', 'Sign-in was cancelled.');
    }
    await _saveTokens(object(result.data), epoch);
    try {
      final raw = object(
        (await request(const DataRequest('GET', '/auth/me'))).data,
      );
      final profile = ProfileMapper.fromJson(raw);
      await _bindCommandAccount(profile);
      if (source is CachedDataSource) {
        await (source as CachedDataSource).bind(
          '$namespace:${raw['tenantId']}:${profile.id}:${profile.role}',
        );
      }
      return profile;
    } catch (_) {
      if (epoch == _generation) await _eraseSession();
      rethrow;
    }
  }

  @override
  Future<Profile> demoLogin(String role) async {
    if (source is! LocalDataSource) {
      throw const DataFailure(
        403,
        'FORBIDDEN',
        'Demo accounts are unavailable in remote mode.',
      );
    }
    _workspaceGeneration++;
    (source as LocalDataSource).setDemoRole(role);
    final profile = ProfileMapper.fromJson(
      object((await source.send(const DataRequest('GET', '/auth/me'))).data),
    );
    await _bindCommandAccount(profile);
    return profile;
  }

  void _requireGeneration(int generation) {
    if (generation != _workspaceGeneration) {
      throw const DataFailure(
        0,
        'SESSION_CHANGED',
        'Your workspace changed. Refresh before retrying this action.',
      );
    }
  }

  @override
  Future<DataResponse> request(DataRequest r) async {
    final generation = _workspaceGeneration;
    final observed = _accessToken;
    try {
      final result = await source.send(r);
      _requireGeneration(generation);
      return result;
    } on DataFailure catch (e) {
      _requireGeneration(generation);
      if (e.status != 401 ||
          isLocal ||
          [
            '/auth/login',
            '/auth/refresh',
            '/auth/logout',
            '/tenants',
          ].contains(r.path)) {
        rethrow;
      }
      try {
        if (observed == _accessToken) await _refresh();
        _requireGeneration(generation);
        final result = await source.send(
          r,
        ); // Same command object and key, once.
        _requireGeneration(generation);
        return result;
      } on DataFailure catch (failure) {
        _requireGeneration(generation);
        if (failure.status == 401) {
          await _eraseSession();
          if (!_expired.isClosed) _expired.add(null);
        }
        rethrow;
      }
    }
  }

  Future<void> _refresh() async {
    if (_refreshing != null) return _refreshing;
    final pending = _rotate();
    _refreshing = pending;
    try {
      await pending;
    } finally {
      if (identical(_refreshing, pending)) _refreshing = null;
    }
  }

  Future<void> _rotate() async {
    final epoch = _generation;
    final saved = await secrets.read('$namespace.tokens');
    final refresh = saved == null
        ? null
        : object(jsonDecode(saved))['refreshToken'] as String?;
    if (refresh == null) {
      throw const DataFailure(401, 'SESSION_EXPIRED', 'Please sign in again.');
    }
    try {
      final result = await source.send(
        DataRequest('POST', '/auth/refresh', body: {'refreshToken': refresh}),
      );
      if (epoch != _generation) {
        throw const DataFailure(
          401,
          'SESSION_CHANGED',
          'Please sign in again.',
        );
      }
      await _saveTokens(object(result.data), epoch);
    } on DataFailure catch (e) {
      if (e.status == 401 && epoch == _generation) {
        await _eraseSession();
      }
      rethrow;
    }
  }

  Future<void> _saveTokens(JsonMap tokens, int epoch) =>
      _credentialOperation(() async {
        final access = requiredText(tokens, 'accessToken');
        final refresh = requiredText(tokens, 'refreshToken');
        if (epoch != _generation) {
          throw const DataFailure(401, 'SESSION_CHANGED', 'Sign in again.');
        }
        await secrets.write(
          '$namespace.tokens',
          jsonEncode({'accessToken': access, 'refreshToken': refresh}),
        );
        if (epoch != _generation) {
          await secrets.remove('$namespace.tokens');
          throw const DataFailure(401, 'SESSION_CHANGED', 'Sign in again.');
        }
        _accessToken = access;
      });
  Future<void> _eraseSession() async {
    clearSession(invalidateWorkspace: false);
    if (source is CachedDataSource) await (source as CachedDataSource).unbind();
    await _credentialOperation(() => secrets.remove('$namespace.tokens'));
  }

  @override
  Future<void> logout() async {
    _workspaceGeneration++;
    final generation = ++_generation;
    try {
      try {
        await source.send(const DataRequest('DELETE', '/form-drafts'));
      } catch (_) {
        // Session erasure still proceeds when the server is unavailable.
      }
      if (!isLocal) {
        String? saved;
        await _credentialOperation(() async {
          saved = await secrets.read('$namespace.tokens');
        });
        if (generation != _generation) return;
        final refresh = saved == null
            ? null
            : object(jsonDecode(saved!))['refreshToken'] as String?;
        await source.send(
          DataRequest(
            'POST',
            '/auth/logout',
            body: {'refreshToken': refresh},
            idempotencyKey: commandKey(),
          ),
        );
      }
    } finally {
      await PendingCommandKeys(secrets, namespace).clearAll();
      await secrets.remove('$namespace.pending.account');
      if (generation == _generation) await _eraseSession();
    }
  }

  void close() {
    clearSession();
    source.close();
    unawaited(_expired.close());
  }
}
