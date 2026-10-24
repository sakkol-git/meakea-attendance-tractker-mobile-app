abstract interface class PreferencesGateway {
  Future<bool?> read(String key);
  Future<void> write(String key, bool value);
}
