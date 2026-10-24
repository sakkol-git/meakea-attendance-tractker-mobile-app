import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:hrflow_mobile/core/protocol.dart';

class RemoteDataSource implements DataSource {
  @override
  String get mode => 'remote';
  final Uri _base;
  final String? Function() _token;
  final http.Client _client;
  final Duration timeout;

  RemoteDataSource(
    String baseUrl,
    String? Function() token, {
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _base = _validateBase(baseUrl),
       _token = token,
       _client = client ?? http.Client();

  static Uri _validateBase(String value) {
    final uri = Uri.tryParse(value);
    final local = ['localhost', '127.0.0.1', '::1'].contains(uri?.host);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && !(local && uri.scheme == 'http')) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !uri.path.replaceFirst(RegExp(r'/$'), '').endsWith('/api/v1')) {
      throw const DataFailure(
        0,
        'INVALID_BASE_URL',
        'Use HTTPS with /api/v1, no credentials, query or fragment; HTTP is allowed for loopback development.',
      );
    }
    return uri;
  }

  @override
  Future<DataResponse> send(DataRequest request) async {
    validateRequest(request);
    final uri = _base.replace(
      path: _base.path.replaceFirst(RegExp(r'/$'), '') + request.path,
      queryParameters: request.query.isEmpty ? null : request.query,
    );
    final token = _token();
    final wire = http.Request(request.method, uri)..followRedirects = false;
    wire.headers['Accept'] = 'application/json, application/problem+json';
    if (token != null && token.isNotEmpty) {
      wire.headers['Authorization'] = 'Bearer $token';
    }
    if (request.body != null) {
      wire.headers['Content-Type'] = 'application/json';
      wire.body = jsonEncode(request.body);
    }
    if (request.idempotencyKey != null) {
      wire.headers['Idempotency-Key'] = request.idempotencyKey!;
    }
    if (request.ifMatch != null) wire.headers['If-Match'] = request.ifMatch!;
    try {
      final response = await (() async => http.Response.fromStream(
        await _client.send(wire),
      ))().timeout(timeout);
      dynamic data;
      try {
        data = response.statusCode == 204 || response.body.isEmpty
            ? null
            : jsonDecode(response.body);
      } on FormatException {
        throw DataFailure(
          response.statusCode,
          'INVALID_RESPONSE',
          'The API returned an invalid JSON response.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final problem = data is Map ? data : const {};
        throw DataFailure(
          response.statusCode,
          problem['code'] is String
              ? problem['code']
              : 'HTTP_${response.statusCode}',
          problem['detail'] is String
              ? problem['detail']
              : 'The API request failed.',
          traceId: problem['traceId'] is String ? problem['traceId'] : null,
        );
      }
      return DataResponse(
        response.statusCode,
        data,
        etag: response.headers['etag'],
        cacheAllowed:
            !RegExp(
              r'no-store|no-cache',
              caseSensitive: false,
            ).hasMatch(response.headers['cache-control'] ?? '') &&
            response.headers['vary'] != '*',
        maxAgeSeconds: int.tryParse(
          RegExp(r'max-age=(\d+)')
                  .firstMatch(response.headers['cache-control'] ?? '')
                  ?.group(1) ??
              '',
        ),
      );
    } on DataFailure {
      rethrow;
    } on TimeoutException {
      throw const DataFailure(
        0,
        'TIMEOUT',
        'The request timed out. Its outcome may be unknown; retry commands with the same key.',
      );
    } catch (_) {
      throw const DataFailure(
        0,
        'NETWORK_ERROR',
        'The request could not be completed. Its outcome may be unknown; retry commands with the same key.',
      );
    }
  }

  @override
  void close() => _client.close();
}
