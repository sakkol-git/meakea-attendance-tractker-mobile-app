import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hrflow_mobile/features/settings/domain/preferences_gateway.dart';

abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class DeviceSecrets implements SecretStore {
  final FlutterSecureStorage storage;
  const DeviceSecrets([this.storage = const FlutterSecureStorage()]);
  @override
  Future<String?> read(String key) => storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
  @override
  Future<void> remove(String key) => storage.delete(key: key);
}

class MemorySecrets implements SecretStore {
  final Map<String, String> _values = {};
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}

class DevicePreferences implements PreferencesGateway {
  @override
  Future<bool?> read(String key) => SharedPreferencesAsync().getBool(key);
  @override
  Future<void> write(String key, bool value) =>
      SharedPreferencesAsync().setBool(key, value);
}

class MemoryPreferences implements PreferencesGateway {
  final Map<String, bool> values = {};
  @override
  Future<bool?> read(String key) async => values[key];
  @override
  Future<void> write(String key, bool value) async {
    values[key] = value;
  }
}
