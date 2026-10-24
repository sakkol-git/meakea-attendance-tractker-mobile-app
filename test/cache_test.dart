import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/data/cache/cached_source.dart';
import 'package:hrflow_mobile/core/data/cache/store.dart';

class Server implements DataSource {
  @override
  String get mode => 'remote';
  int reads = 0, writes = 0, revision = 1;
  Object? error;
  bool allowCache = true;
  int? maxAge;
  Completer<void>? wait;
  @override
  Future<DataResponse> send(DataRequest r) async {
    if (r.method != 'GET') {
      writes++;
      revision++;
      return DataResponse(200, {'version': revision});
    }
    reads++;
    final value = revision;
    if (wait != null) await wait!.future;
    if (error != null) throw error!;
    return DataResponse(
      200,
      {
        'items': [
          {'name': 'Synthetic employee', 'version': value},
        ],
      },
      etag: '"$value"',
      cacheAllowed: allowCache,
      maxAgeSeconds: maxAge,
    );
  }

  @override
  void close() {}
}

class BrokenDisk implements CacheStore {
  @override
  Future<JsonMap?> read(String key) async => throw StateError('disk');
  @override
  Future<void> write(String key, JsonMap e) async => throw StateError('disk');
  @override
  Future<void> remove(String key) async => throw StateError('disk');
  @override
  Future<Iterable<String>> keys() async => throw StateError('disk');
  @override
  Future<void> close() async {}
}

void main() {
  test('sensitive server form drafts never enter the client cache', () async {
    final server = Server();
    final source = CachedDataSource(server, MemoryCacheStore());
    addTearDown(source.close);
    await source.bind('tenant:employee:hr');
    await source.send(const DataRequest('GET', '/form-drafts/leave'));
    await source.send(const DataRequest('GET', '/form-drafts/leave'));
    expect(server.reads, 2);
    expect(source.hits, 0);
  });

  test(
    'shift edits invalidate assignment snapshots and today attendance together',
    () async {
      final server = Server();
      final source = CachedDataSource(server, MemoryCacheStore());
      await source.bind('tenant:employee:hr');
      const paths = ['/employees/employee-a/shifts', '/attendance/today'];
      for (final path in paths) {
        await source.send(DataRequest('GET', path));
      }
      for (final path in paths) {
        expect((await source.send(DataRequest('GET', path))).fromCache, true);
      }
      await source.send(
        const DataRequest(
          'PATCH',
          '/shifts/shift-a',
          body: {'name': 'Updated shift'},
          ifMatch: '"1"',
        ),
      );
      for (final path in paths) {
        expect((await source.send(DataRequest('GET', path))).fromCache, false);
      }
      expect(server.reads, 4);
      source.close();
    },
  );
  test(
    'server no-store removes an existing entry and max-age shortens freshness',
    () async {
      var now = DateTime.utc(2026, 10, 23);
      final server = Server()..maxAge = 1;
      final source = CachedDataSource(
        server,
        MemoryCacheStore(),
        clock: () => now,
      );
      await source.bind('account');
      const request = DataRequest('GET', '/employees');
      await source.send(request);
      now = now.add(const Duration(seconds: 2));
      server.allowCache = false;
      await source.send(request);
      await source.send(request);
      expect(server.reads, 3);
      server.error = const DataFailure(0, 'TIMEOUT', 'Offline');
      await expectLater(source.send(request), throwsA(isA<DataFailure>()));
      source.close();
    },
  );
  test('malformed stored entries are discarded and fetched again', () async {
    final store = MemoryCacheStore();
    final server = Server();
    final source = CachedDataSource(server, store);
    await source.bind('account');
    const request = DataRequest('GET', '/employees');
    await source.send(request);
    final key = store.entries.keys.single;
    source.close();
    store.entries[key] = {'path': '/employees', 'savedAt': 'broken'};
    final restored = CachedDataSource(server, store);
    await restored.bind('account');
    await restored.send(request);
    expect(server.reads, 2);
    restored.close();
  });
  test(
    'fresh reads are cached, cloned, and expired balance reads revalidate',
    () async {
      var now = DateTime.utc(2026, 10, 23);
      final server = Server();
      final store = MemoryCacheStore();
      final source = CachedDataSource(server, store, clock: () => now);
      await source.bind('api:tenant-a:employee-a:employee');
      const request = DataRequest('GET', '/leave/balances/me');
      final first = await source.send(request);
      (first.data['items'] as List).clear();
      final second = await source.send(request);
      expect(second.fromCache, true);
      expect(second.data['items'], hasLength(1));
      expect(server.reads, 1);
      now = now.add(const Duration(seconds: 16));
      await source.send(request);
      expect(server.reads, 2);
      source.close();
    },
  );
  test('concurrent identical reads share one upstream call', () async {
    final server = Server()..wait = Completer<void>();
    final source = CachedDataSource(server, MemoryCacheStore());
    await source.bind('a');
    final first = source.send(const DataRequest('GET', '/employees'));
    final second = source.send(const DataRequest('GET', '/employees'));
    await Future<void>.delayed(Duration.zero);
    expect(server.reads, 1);
    server.wait!.complete();
    await Future.wait([first, second]);
    expect(source.coalesced, 1);
    source.close();
  });
  test(
    'mutations invalidate dependent reads and never use cached command results',
    () async {
      final server = Server();
      final source = CachedDataSource(server, MemoryCacheStore());
      await source.bind('a');
      await source.send(const DataRequest('GET', '/leave/balances/me'));
      await source.send(
        DataRequest(
          'POST',
          '/leave/requests',
          idempotencyKey: commandKey(),
          body: {'reason': 'Synthetic'},
        ),
      );
      await source.send(const DataRequest('GET', '/leave/balances/me'));
      expect(server.reads, 2);
      expect(server.writes, 1);
      source.close();
    },
  );
  test('offline fallback is explicitly stale; permission errors never return cached data', () async {
    var now = DateTime.utc(2026, 10, 23);
    final server = Server();
    final source = CachedDataSource(
      server,
      MemoryCacheStore(),
      clock: () => now,
    );
    await source.bind('a');
    const request = DataRequest('GET', '/employees');
    await source.send(request);
    now = now.add(const Duration(minutes: 6));
    server.error = const DataFailure(0, 'NETWORK_ERROR', 'Offline');
    final offline = await source.send(request);
    expect(offline.stale, true);
    expect(offline.fromCache, true);
    server.error = const DataFailure(403, 'FORBIDDEN', 'Denied');
    await expectLater(
      source.send(request),
      throwsA(isA<DataFailure>().having((e) => e.status, 'status', 403)),
    );
    source.close();
  });
  test('stale reads expire completely after 24 hours', () async {
    var now = DateTime.utc(2026, 10, 23);
    final server = Server();
    final source = CachedDataSource(
      server,
      MemoryCacheStore(),
      clock: () => now,
    );
    await source.bind('a');
    const request = DataRequest('GET', '/employees');
    await source.send(request);
    now = now.add(const Duration(hours: 25));
    server.error = const DataFailure(0, 'NETWORK_ERROR', 'Offline');
    await expectLater(source.send(request), throwsA(isA<DataFailure>()));
    source.close();
  });
  test(
    'account switch cannot publish in-flight data from an old account',
    () async {
      final server = Server()..wait = Completer<void>();
      final source = CachedDataSource(server, MemoryCacheStore());
      await source.bind('tenant-a:alice');
      final old = source.send(const DataRequest('GET', '/employees'));
      await Future<void>.delayed(Duration.zero);
      await source.bind('tenant-b:bob');
      server.wait!.complete();
      await expectLater(
        old,
        throwsA(
          isA<DataFailure>().having((e) => e.code, 'code', 'CACHE_INVALIDATED'),
        ),
      );
      server.wait = null;
      server.revision = 5;
      final fresh = await source.send(const DataRequest('GET', '/employees'));
      expect(fresh.data['items'][0]['version'], 5);
      source.close();
    },
  );
  test(
    'bounded LRU evicts old records and keeps storage within entry cap',
    () async {
      final store = MemoryCacheStore();
      final server = Server();
      var now = DateTime.utc(2026);
      final source = CachedDataSource(
        server,
        store,
        maxEntries: 2,
        clock: () => now,
      );
      await source.bind('a');
      for (final path in ['/employees', '/departments', '/shifts']) {
        await source.send(DataRequest('GET', path));
        now = now.add(const Duration(seconds: 1));
      }
      expect((await store.keys()).length, 2);
      await source.send(const DataRequest('GET', '/employees'));
      expect(server.reads, 4);
      source.close();
    },
  );
  test('cache storage failures cannot turn a successful server mutation into failure', () async {
    final server = Server();
    final source = CachedDataSource(server, BrokenDisk());
    await source.bind('a');
    await source.send(const DataRequest('GET', '/employees'));
    final response = await source.send(
      DataRequest(
        'POST',
        '/employees',
        body: {'name': 'Synthetic'},
        idempotencyKey: commandKey(),
      ),
    );
    expect(response.status, 200);
    expect(server.writes, 1);
    source.close();
  });
  test('unbound identity and authentication reads are never cached', () async {
    final server = Server();
    final source = CachedDataSource(server, MemoryCacheStore());
    await source.send(const DataRequest('GET', '/employees'));
    await source.send(const DataRequest('GET', '/employees'));
    await source.bind('a');
    await source.send(const DataRequest('GET', '/auth/me'));
    await source.send(const DataRequest('GET', '/auth/me'));
    expect(server.reads, 4);
    source.close();
  });
}
