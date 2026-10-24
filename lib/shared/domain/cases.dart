/// Immutable client-facing business record used by feature administration screens.
class CaseRecord {
  final String id, title, status;
  final int version;
  final String? revision;
  final Map<String, dynamic> values;
  const CaseRecord({
    required this.id,
    required this.title,
    required this.status,
    required this.version,
    required this.values,
    this.revision,
  });
  String get etag => revision ?? '"$version"';
}

abstract interface class CaseGateway {
  Future<List<CaseRecord>> cases(
    String collection, {
    Map<String, String> filters = const {},
  });
  Future<Map<String, dynamic>> changeCase(
    String action,
    String? id,
    Map<String, dynamic> input, {
    required String key,
    String? etag,
  });
}
