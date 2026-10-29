import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

typedef JsonMap = Map<String, dynamic>;

class DataRequest {
  final String method;
  final String path;
  final Map<String, String> query;
  final JsonMap? body;
  final String? idempotencyKey;
  final String? ifMatch;
  final String? responseType;
  final Uint8List? bytes;
  final String? contentType;
  const DataRequest(
    this.method,
    this.path, {
    this.query = const {},
    this.body,
    this.idempotencyKey,
    this.ifMatch,
    this.responseType,
    this.bytes,
    this.contentType,
  });
}

class DataResponse {
  final int status;
  final dynamic data;
  final String? etag;
  final bool fromCache, stale, cacheAllowed;
  final int? maxAgeSeconds;
  const DataResponse(
    this.status,
    this.data, {
    this.etag,
    this.fromCache = false,
    this.stale = false,
    this.cacheAllowed = true,
    this.maxAgeSeconds,
  });
}

abstract interface class DataSource {
  String get mode;
  Future<DataResponse> send(DataRequest request);
  void close();
}

class DataFailure implements Exception {
  final int status;
  final String code;
  final String message;
  final String? traceId;
  const DataFailure(this.status, this.code, this.message, {this.traceId});
  @override
  String toString() => '$code: $message';
}

void validateRequest(DataRequest request) {
  final privateFile = RegExp(
    r'^/requests/[a-z0-9-]+/attachments/[a-z0-9-]+/(file|upload)$',
  );
  if (request.bytes != null || request.contentType != null) {
    if (request.method != 'PUT' ||
        !privateFile.hasMatch(request.path) ||
        !request.path.endsWith('/upload') ||
        (request.bytes?.isEmpty ?? true) ||
        request.bytes!.length > 10 * 1024 * 1024 ||
        request.body != null ||
        ![
          'application/pdf',
          'image/png',
          'image/jpeg',
        ].contains(request.contentType)) {
      throw const DataFailure(
        0,
        'INVALID_PATH',
        'Use a bounded private attachment upload.',
      );
    }
  }
  if (request.responseType != null &&
      (request.method != 'GET' ||
          (request.responseType == 'bytes'
              ? !privateFile.hasMatch(request.path) ||
                    !request.path.endsWith('/file')
              : request.responseType != 'csv' ||
                    !RegExp(r'^/reports/exports/[a-z0-9-]+/download$')
                        .hasMatch(request.path)))) {
    throw const DataFailure(
      0,
      'INVALID_PATH',
      'CSV downloads require a private export path.',
    );
  }
  if (!['GET', 'POST', 'PUT', 'PATCH', 'DELETE'].contains(request.method) ||
      !RegExp(r'^/[a-z0-9/-]+$').hasMatch(request.path) ||
      request.path.contains('//')) {
    throw const DataFailure(
      0,
      'INVALID_PATH',
      'Use a supported method and relative domain path without query or origin.',
    );
  }
  if (request.method == 'POST' &&
      !['/auth/login', '/auth/refresh'].contains(request.path) &&
      !RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(request.idempotencyKey ?? '')) {
    throw const DataFailure(
      428,
      'IDEMPOTENCY_REQUIRED',
      'Provide a UUID v4 command key and preserve it when retrying.',
    );
  }
}

String commandKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

dynamic copyJson(dynamic value) => jsonDecode(jsonEncode(value));

String canonicalJson(dynamic value) {
  dynamic sort(dynamic item) {
    if (item is Map) {
      final keys = item.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: sort(item[key])};
    }
    if (item is List) return item.map(sort).toList();
    return item;
  }

  return jsonEncode(sort(value));
}
