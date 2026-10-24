import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/data/cache/store.dart';

/// GET-only read-through cache. Identity is bound only after authenticated profile validation.
class CachedDataSource implements DataSource {
  final DataSource upstream;
  final CacheStore store;
  final DateTime Function() now;
  final int maxEntries, maxBytes;
  final Duration maxStale;
  String? _scope;
  int _epoch = 0;
  final Map<String, JsonMap> _memory = {};
  final Map<String, Future<DataResponse>> _inflight = {};
  final Set<String> _stale = {};
  final _changes = StreamController<bool>.broadcast();
  int hits = 0, misses = 0, coalesced = 0;
  CachedDataSource(
    this.upstream,
    CacheStore storage, {
    DateTime Function()? clock,
    this.maxEntries = 128,
    this.maxBytes = 4 * 1024 * 1024,
    this.maxStale = const Duration(hours: 24),
  }) : now = clock ?? DateTime.now,
       store = ResilientCacheStore(storage);
  @override
  String get mode => upstream.mode;
  Stream<bool> get staleChanges => _changes.stream;
  void _notify() {
    if (!_changes.isClosed) _changes.add(_stale.isNotEmpty);
  }

  Future<void> bind(String identity) async {
    final hash = sha256.convert(utf8.encode(identity)).toString();
    if (hash == _scope) return;
    await clear();
    _scope = hash;
    _epoch++;
  }

  Future<void> clear() async {
    _epoch++;
    _memory.clear();
    _inflight.clear();
    _stale.clear();
    _notify();
    final prefix = _scope == null ? null : '$_scope:';
    if (prefix != null) {
      for (final key in await store.keys()) {
        if (key.startsWith(prefix)) await store.remove(key);
      }
    }
  }

  Future<void> unbind() async {
    await clear();
    _scope = null;
  }

  Duration _ttl(String path) =>
      path.startsWith('/leave/balances') ||
          path.startsWith('/leave/admin/balances')
      ? const Duration(seconds: 15)
      : path.startsWith('/attendance') ||
            path.contains('/pending') ||
            path.startsWith('/notifications')
      ? const Duration(seconds: 30)
      : path.startsWith('/employees') ||
            path.startsWith('/departments') ||
            path.startsWith('/shifts') ||
            path.startsWith('/holidays') ||
            path.startsWith('/positions') ||
            path.startsWith('/materials') ||
            path == '/leave/types'
      ? const Duration(minutes: 5)
      : const Duration(minutes: 1);
  bool _cacheable(DataRequest r) =>
      r.method == 'GET' &&
      _scope != null &&
      !r.path.startsWith('/auth') &&
      !r.path.contains('/attachments') &&
      !r.path.contains('/exports') &&
      !r.path.startsWith('/audit');
  String _key(DataRequest r) =>
      '$_scope:${canonicalJson({'path': r.path, 'query': r.query})}';
  Future<void> _invalidate(String path) async {
    _epoch++;
    final prefixes = path.startsWith('/leave')
        ? ['/leave', '/attendance', '/reports', '/notifications']
        : path.startsWith('/attendance')
        ? ['/attendance', '/leave', '/reports', '/notifications']
        : path.startsWith('/requests')
        ? ['/requests', '/reports', '/notifications', '/materials']
        : path.startsWith('/notifications')
        ? ['/notifications']
        : path.startsWith('/materials')
        ? ['/materials', '/requests', '/reports']
        : path.startsWith('/employees')
        ? [
            '/employees',
            '/shift-assignments',
            '/leave',
            '/requests',
            '/attendance',
            '/reports',
            '/notifications',
          ]
        : path.startsWith('/shifts')
        ? ['/shifts', '/employees', '/attendance', '/reports']
        : [path.split('/').take(2).join('/'), '/reports', '/attendance'];
    for (final key in (await store.keys()).toList()) {
      final entry = _memory[key] ?? await store.read(key);
      if (key.startsWith('$_scope:') &&
          entry != null &&
          (!_valid(entry) ||
              prefixes.any((p) => (entry['path'] as String).startsWith(p)))) {
        _memory.remove(key);
        _stale.remove(key);
        await store.remove(key);
      }
    }
    _notify();
  }

  bool _valid(JsonMap entry) =>
      entry['path'] is String &&
      entry['savedAt'] is int &&
      entry['accessedAt'] is int &&
      entry['status'] == 200 &&
      (entry['etag'] == null || entry['etag'] is String) &&
      (entry['maxAgeSeconds'] == null || entry['maxAgeSeconds'] is int);

  DataResponse _response(JsonMap entry, {bool stale = false}) => DataResponse(
    entry['status'] as int,
    copyJson(entry['data']),
    etag: entry['etag'] as String?,
    fromCache: true,
    stale: stale,
  );
  @override
  Future<DataResponse> send(DataRequest r) async {
    if (!_cacheable(r)) {
      late final DataResponse result;
      try {
        result = await upstream.send(r);
      } on DataFailure catch (failure) {
        if (r.method != 'GET' && failure.status == 412) {
          await _invalidate(r.path);
        }
        rethrow;
      }
      if (r.method != 'GET' && !r.path.startsWith('/auth')) {
        await _invalidate(r.path);
      }
      return result;
    }
    final key = _key(r);
    final inFlight = _inflight[key];
    if (inFlight != null) {
      coalesced++;
      return _copy(await inFlight);
    }
    final future = _read(r, key);
    _inflight[key] = future;
    try {
      return _copy(await future);
    } finally {
      if (identical(_inflight[key], future)) _inflight.remove(key);
    }
  }

  DataResponse _copy(DataResponse r) => DataResponse(
    r.status,
    copyJson(r.data),
    etag: r.etag,
    fromCache: r.fromCache,
    stale: r.stale,
    cacheAllowed: r.cacheAllowed,
    maxAgeSeconds: r.maxAgeSeconds,
  );
  Future<DataResponse> _read(DataRequest request, String key) async {
    final epoch = _epoch;
    var entry = _memory[key];
    entry ??= await store.read(key);
    if (entry != null && !_valid(entry)) {
      _memory.remove(key);
      await store.remove(key);
      entry = null;
    }
    if (entry != null && epoch == _epoch) {
      _memory[key] = entry;
      final age = now().millisecondsSinceEpoch - (entry['savedAt'] as int);
      final serverTtl = entry['maxAgeSeconds'] as int?;
      final policyTtl = _ttl(request.path).inMilliseconds;
      final ttl = serverTtl == null
          ? policyTtl
          : (serverTtl * 1000).clamp(0, policyTtl);
      if (age >= 0 && age < ttl) {
        hits++;
        entry['accessedAt'] = now().millisecondsSinceEpoch;
        _stale.remove(key);
        _notify();
        return _response(entry);
      }
    }
    misses++;
    try {
      final result = await upstream.send(request);
      // Never publish an old account/invalidation response as the current result.
      if (epoch != _epoch) {
        throw const DataFailure(
          0,
          'CACHE_INVALIDATED',
          'Workspace data changed. Refresh this view.',
        );
      }
      final candidate = <String, dynamic>{
        'path': request.path,
        'maxAgeSeconds': result.maxAgeSeconds,
        'status': result.status,
        'data': copyJson(result.data),
        'etag': result.etag,
        'savedAt': now().millisecondsSinceEpoch,
        'accessedAt': now().millisecondsSinceEpoch,
      };
      if (result.cacheAllowed &&
          result.status == 200 &&
          utf8.encode(jsonEncode(candidate)).length <= 256 * 1024) {
        _memory[key] = candidate;
        await store.write(key, candidate);
        await _evict();
      } else {
        _memory.remove(key);
        await store.remove(key);
      }
      _stale.remove(key);
      _notify();
      return result;
    } on DataFailure catch (e) {
      if ((e.status == 401 || e.status == 403) && epoch == _epoch) {
        await clear();
      }
      final age = entry == null
          ? null
          : now().millisecondsSinceEpoch - (entry['savedAt'] as int);
      if (epoch == _epoch &&
          entry != null &&
          age != null &&
          age >= 0 &&
          age <= maxStale.inMilliseconds &&
          ['NETWORK_ERROR', 'TIMEOUT'].contains(e.code)) {
        _stale.add(key);
        _notify();
        return _response(entry, stale: true);
      }
      rethrow;
    }
  }

  Future<void> _evict() async {
    final entries = <({String key, int touched, int bytes})>[];
    for (final key in await store.keys()) {
      final value = _memory[key] ?? await store.read(key);
      if (value == null) continue;
      if (!_valid(value)) {
        await store.remove(key);
        _memory.remove(key);
        continue;
      }
      entries.add((
        key: key,
        touched: value['accessedAt'] as int,
        bytes: utf8.encode(jsonEncode(value)).length,
      ));
    }
    entries.sort((a, b) => a.touched.compareTo(b.touched));
    var bytes = entries.fold<int>(0, (sum, e) => sum + e.bytes);
    var count = entries.length;
    for (final e in entries) {
      if (count <= maxEntries && bytes <= maxBytes) break;
      await store.remove(e.key);
      _memory.remove(e.key);
      _stale.remove(e.key);
      bytes -= e.bytes;
      count--;
    }
    // Memory is bounded by the same count; no unbounded DTO or response retention.
  }

  @override
  void close() {
    upstream.close();
    unawaited(store.close());
    unawaited(_changes.close());
  }
}
