import '../protocol.dart';

JsonMap object(dynamic value) {
  if (value is! Map<String, dynamic>) {
    throw const DataFailure(
      0,
      'CONTRACT_MISMATCH',
      'The server returned an unexpected object.',
    );
  }
  return value;
}

String requiredText(JsonMap j, String key) {
  if (j[key] is! String || (j[key] as String).trim().isEmpty) {
    throw DataFailure(0, 'CONTRACT_MISMATCH', 'Missing $key in API response.');
  }
  return j[key] as String;
}

int requiredInt(JsonMap j, String key) {
  final value = j[key];
  if (value is! int || value < 0) {
    throw DataFailure(0, 'CONTRACT_MISMATCH', 'Invalid $key in API response.');
  }
  return value;
}

List<JsonMap> items(dynamic value) {
  final body = object(value);
  if (body['items'] is! List) {
    throw const DataFailure(
      0,
      'CONTRACT_MISMATCH',
      'The server returned an unexpected collection.',
    );
  }
  return (body['items'] as List).map(object).toList();
}

String text(JsonMap j, String key, [String fallback = '']) {
  final value = j[key];
  if (value == null) return fallback;
  if (value is! String) {
    throw DataFailure(0, 'CONTRACT_MISMATCH', 'Invalid $key in API response.');
  }
  return value.trim().isEmpty ? fallback : value;
}

DateTime timestamp(JsonMap j, String key) {
  final value = DateTime.tryParse(requiredText(j, key));
  if (value == null) {
    throw DataFailure(0, 'CONTRACT_MISMATCH', 'Invalid $key timestamp.');
  }
  return value;
}

double number(JsonMap j, String key) {
  final value = j[key];
  if (value is! num || !value.isFinite) {
    throw DataFailure(0, 'CONTRACT_MISMATCH', 'Invalid $key amount.');
  }
  return value.toDouble();
}

dynamic freeze(dynamic value) => value is Map<String, dynamic>
    ? Map<String, dynamic>.unmodifiable(
        value.map((key, item) => MapEntry(key, freeze(item))),
      )
    : value is List
    ? List<dynamic>.unmodifiable(value.map(freeze))
    : value;

String dateOnly(JsonMap j, String key) {
  final value = requiredText(j, key);
  final parsed = DateTime.tryParse(value);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
      parsed == null ||
      parsed.toIso8601String().substring(0, 10) != value) {
    throw DataFailure(0, 'CONTRACT_MISMATCH', 'Invalid $key date.');
  }
  return value;
}
