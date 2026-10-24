abstract interface class ResourceGateway {
  Future<dynamic> get(String path);
  Future<List<Map<String, dynamic>>> collection(String path);
  Future<Object?> command(
    String path, {
    Map<String, dynamic>? body,
    String? etag,
    String? key,
  });
  Future<void> saveEntity(
    String path,
    Map<String, dynamic> values, {
    Map<String, dynamic>? existing,
    String? key,
  });
  Future<void> refresh();
}
