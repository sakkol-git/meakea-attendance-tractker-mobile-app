import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/protocol.dart';

/// External signed transfers never carry API credentials or follow redirects.
Future<Uint8List> signedTransfer(
  String method,
  Uri url, {
  Map<String, String> headers = const {},
  Uint8List? bytes,
  http.Client? client,
}) async {
  if (headers.keys.any(
    (name) => ['authorization', 'cookie', 'host'].contains(name.toLowerCase()),
  )) {
    throw const DataFailure(
      0,
      'INVALID_FILE_URL',
      'Signed transfers cannot carry API credentials.',
    );
  }
  final transport = client ?? http.Client();
  try {
    final request = http.Request(method, url)
      ..followRedirects = false
      ..headers.addAll(headers);
    if (bytes != null) request.bodyBytes = bytes;
    final response = await (() async => http.Response.fromStream(
      await transport.send(request),
    ))().timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        response.bodyBytes.length > 10 * 1024 * 1024) {
      throw const DataFailure(
        0,
        'FILE_TRANSFER_FAILED',
        'The file transfer failed. Retry the same attachment.',
      );
    }
    return response.bodyBytes;
  } finally {
    if (client == null) transport.close();
  }
}
