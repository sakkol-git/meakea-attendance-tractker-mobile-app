import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/data/json.dart';
import 'package:hrflow_mobile/shared/domain/workflow.dart';
import 'package:hrflow_mobile/core/data/resource_repository.dart';

mixin AttachmentsMethods on ResourceRepository {
  Future<void> attach(
    WorkflowRecord record,
    String name,
    Uint8List bytes,
  ) async {
    final workspace = client.workspaceRevision;
    if (bytes.length > 10 * 1024 * 1024) {
      throw const DataFailure(
        422,
        'FILE_TOO_LARGE',
        'Choose a file smaller than 10 MB.',
      );
    }
    final ext = name.split('.').last.toLowerCase();
    final type = switch (ext) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => throw const DataFailure(
        422,
        'FILE_TYPE_UNSUPPORTED',
        'Choose a PDF, PNG or JPEG file.',
      ),
    };
    if (client.isLocal) {
      await command(
        '${record.kind == 'leave' ? '/leave/requests' : '/requests'}/${record.id}/attachments',
        body: {
          'name': name,
          'size': bytes.length,
          'content': base64Encode(bytes),
        },
      );
      return;
    }
    final presign = object(
      (await command(
        '${record.kind == 'leave' ? '/leave/requests' : '/requests'}/${record.id}/attachments/presign',
        body: {
          'fileName': name,
          'contentType': type,
          'size': bytes.length,
          'sha256': sha256.convert(bytes).toString(),
        },
      )).data,
    );
    final url = fileUrl(requiredText(presign, 'uploadUrl'));
    final headers = <String, String>{'Content-Type': type};
    final requiredHeaders = presign['requiredHeaders'];
    if (requiredHeaders != null) {
      for (final header in object(requiredHeaders).entries) {
        if (header.value is! String ||
            [
              'authorization',
              'cookie',
              'host',
            ].contains(header.key.toLowerCase())) {
          throw const DataFailure(
            0,
            'CONTRACT_MISMATCH',
            'Invalid signed upload headers.',
          );
        }
        headers[header.key] = header.value as String;
      }
    }
    final response = await http
        .put(url, headers: headers, body: bytes)
        .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const DataFailure(
        0,
        'UPLOAD_FAILED',
        'Upload failed. Retry the attachment.',
      );
    }
    requireWorkspace(workspace);
    await command(
      '${record.kind == 'leave' ? '/leave/requests' : '/requests'}/${record.id}/attachments/${requiredText(presign, 'attachmentId')}/complete',
    );
  }

  Future<Uint8List> download(WorkflowRecord record, JsonMap attachment) async {
    final workspace = client.workspaceRevision;
    if (client.isLocal) {
      final file = object(
        await get(
          '${record.kind == 'leave' ? '/leave/requests' : '/requests'}/${record.id}/attachments/${attachment['id']}',
        ),
      );
      return base64Decode(requiredText(file, 'content'));
    }
    final file = object(
      await get(
        '${record.kind == 'leave' ? '/leave/requests' : '/requests'}/${record.id}/attachments/${attachment['id']}/download',
      ),
    );
    final response = await http
        .get(fileUrl(requiredText(file, 'downloadUrl')))
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw const DataFailure(
        0,
        'DOWNLOAD_FAILED',
        'Could not download this attachment.',
      );
    }
    requireWorkspace(workspace);
    return response.bodyBytes;
  }

  Uri fileUrl(String value) {
    final u = Uri.tryParse(value);
    const apiBase = String.fromEnvironment('API_BASE_URL');
    const configured = String.fromEnvironment('FILE_ORIGINS');
    final trustedOrigins = <String>{
      if (Uri.tryParse(apiBase)?.hasAuthority == true)
        Uri.parse(apiBase).origin,
      for (final origin in configured.split(','))
        if (Uri.tryParse(origin.trim())?.hasAuthority == true)
          Uri.parse(origin.trim()).origin,
    };
    if (u == null ||
        u.scheme != 'https' ||
        u.host.isEmpty ||
        u.userInfo.isNotEmpty ||
        (trustedOrigins.isNotEmpty && !trustedOrigins.contains(u.origin))) {
      throw const DataFailure(
        0,
        'INVALID_FILE_URL',
        'The signed file URL is outside the configured storage origins.',
      );
    }
    return u;
  }
}
