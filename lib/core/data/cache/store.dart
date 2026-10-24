import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'package:hrflow_mobile/core/data/storage.dart';
import 'package:hrflow_mobile/core/protocol.dart';

abstract interface class CacheStore {
  Future<JsonMap?> read(String key);
  Future<void> write(String key, JsonMap entry);
  Future<void> remove(String key);
  Future<Iterable<String>> keys();
  Future<void> close();
}

class MemoryCacheStore implements CacheStore {
  final Map<String, JsonMap> entries = {};
  @override
  Future<JsonMap?> read(String key) async =>
      entries[key] == null ? null : copyJson(entries[key]) as JsonMap;
  @override
  Future<void> write(String key, JsonMap entry) async {
    entries[key] = copyJson(entry) as JsonMap;
  }

  @override
  Future<void> remove(String key) async {
    entries.remove(key);
  }

  @override
  Future<Iterable<String>> keys() async => entries.keys.toList();
  @override
  Future<void> close() async {}
}

class EncryptedCacheStore implements CacheStore {
  final Box<String> _box;
  EncryptedCacheStore._(this._box);
  static Future<EncryptedCacheStore> open(
    String namespace,
    SecretStore secrets,
  ) async {
    await Hive.initFlutter();
    final id = sha256
        .convert(utf8.encode(namespace))
        .toString()
        .substring(0, 24);
    final keyName = 'hrflow.cache.key.$id';
    var saved = await secrets.read(keyName);
    if (saved == null) {
      saved = base64Encode(Hive.generateSecureKey());
      await secrets.write(keyName, saved);
    }
    final box = await Hive.openBox<String>(
      'hrflow_cache_v1_$id',
      encryptionCipher: HiveAesCipher(base64Decode(saved)),
    );
    return EncryptedCacheStore._(box);
  }

  @override
  Future<JsonMap?> read(String key) async {
    final value = _box.get(key);
    if (value == null) return null;
    try {
      return jsonDecode(value) as JsonMap;
    } catch (_) {
      await _box.delete(key);
      return null;
    }
  }

  @override
  Future<void> write(String key, JsonMap entry) =>
      _box.put(key, jsonEncode(entry));
  @override
  Future<void> remove(String key) => _box.delete(key);
  @override
  Future<Iterable<String>> keys() async => _box.keys.cast<String>().toList();
  @override
  Future<void> close() => _box.close();
}

/// Storage failure degrades only to memory containing remote responses, never plaintext disk or demo data.
class ResilientCacheStore implements CacheStore {
  final CacheStore primary;
  final MemoryCacheStore memory = MemoryCacheStore();
  bool degraded = false;
  ResilientCacheStore(this.primary);
  @override
  Future<JsonMap?> read(String key) async {
    if (degraded) return memory.read(key);
    try {
      final value = await primary.read(key);
      if (value != null) await memory.write(key, value);
      return value;
    } catch (_) {
      degraded = true;
      return memory.read(key);
    }
  }

  @override
  Future<void> write(String key, JsonMap entry) async {
    await memory.write(key, entry);
    if (!degraded) {
      try {
        await primary.write(key, entry);
      } catch (_) {
        degraded = true;
      }
    }
  }

  @override
  Future<void> remove(String key) async {
    await memory.remove(key);
    if (!degraded) {
      try {
        await primary.remove(key);
      } catch (_) {
        degraded = true;
      }
    }
  }

  @override
  Future<Iterable<String>> keys() async {
    final keys = (await memory.keys()).toSet();
    if (!degraded) {
      try {
        keys.addAll(await primary.keys());
      } catch (_) {
        degraded = true;
      }
    }
    return keys;
  }

  @override
  Future<void> close() async {
    await memory.close();
    try {
      await primary.close();
    } catch (_) {}
  }
}
