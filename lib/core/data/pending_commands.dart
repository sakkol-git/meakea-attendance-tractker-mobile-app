import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hrflow_mobile/core/protocol.dart';

import 'storage.dart';

/// Secure, account-scoped command keys for safe retries after process loss.
class PendingCommandKeys {
  final SecretStore store;
  final String namespace;
  PendingCommandKeys(this.store, this.namespace);

  String _slot(String scope) =>
      '$namespace.pending.${sha256.convert(utf8.encode(scope))}';
  String get _index => '$namespace.pending.index';

  Future<String> acquire(String scope, Object? payload) async {
    final slot = _slot(scope);
    final fingerprint = sha256
        .convert(utf8.encode(canonicalJson(payload)))
        .toString();
    final saved = await store.read(slot);
    if (saved != null) {
      final decoded = jsonDecode(saved);
      if (decoded is Map &&
          decoded['fingerprint'] == fingerprint &&
          decoded['key'] is String) {
        return decoded['key'] as String;
      }
    }
    final key = commandKey();
    await store.write(
      slot,
      jsonEncode({'fingerprint': fingerprint, 'key': key}),
    );
    final slots = (jsonDecode(
      await store.read(_index) ?? '[]',
    ) as List).cast<String>().toSet()..add(slot);
    await store.write(_index, jsonEncode(slots.toList()));
    return key;
  }

  Future<void> clear(String scope) async {
    final slot = _slot(scope);
    await store.remove(slot);
    final slots = (jsonDecode(
      await store.read(_index) ?? '[]',
    ) as List).cast<String>().toSet()..remove(slot);
    if (slots.isEmpty) {
      await store.remove(_index);
    } else {
      await store.write(_index, jsonEncode(slots.toList()));
    }
  }

  Future<void> clearAll() async {
    final slots = (jsonDecode(await store.read(_index) ?? '[]') as List)
        .cast<String>();
    for (final slot in slots) {
      await store.remove(slot);
    }
    await store.remove(_index);
  }
}
