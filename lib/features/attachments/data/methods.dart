import 'dart:convert';
import 'dart:typed_data';

import 'signed_transfer.dart';

import 'package:crypto/crypto.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/data/json.dart';
import 'package:hrflow_mobile/core/data/pending_commands.dart';
import 'package:hrflow_mobile/shared/domain/workflow.dart';
import 'package:hrflow_mobile/core/data/resource_repository.dart';

mixin AttachmentsMethods on ResourceRepository {
  Future<void> attach(
    WorkflowRecord record,
    String name,
    Uint8List bytes,
  ) async {
    final workspace = client.workspaceRevision;
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
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
    final digest = sha256.convert(bytes).toString();
    final signature = 'attachment:${record.kind}:${record.id}:$name:$digest';
    final keys = PendingCommandKeys(client.secrets, client.namespace);
    final metadata = <String, dynamic>{
      'fileName': name,
      'contentType': type,
      'size': bytes.length,
      'sha256': digest,
    };
    final presignKey = await keys.acquire('$signature:presign', metadata);
    final presign = object(
      (await command(
        '${record.kind == 'leave' ? '/leave/requests' : '/requests'}/${record.id}/attachments/presign',
        body: metadata,
        key: presignKey,
      )).data,
    );
    final attachmentId = requiredText(presign, 'attachmentId');
    final base =
        '${record.kind == 'leave' ? '/leave/requests' : '/requests'}/${record.id}/attachments/$attachmentId';
    final uploadUrl = requiredText(presign, 'uploadUrl');
    if (uploadUrl.startsWith('/')) {
      if (record.kind != 'request' || uploadUrl != '/api/v1$base/upload') {
        throw const DataFailure(
          0,
          'INVALID_FILE_URL',
          'The upload link does not match this private attachment.',
        );
      }
      await client.request(
        DataRequest('PUT', '$base/upload', bytes: bytes, contentType: type),
      );
    } else {
      final url = fileUrl(uploadUrl);
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
      await signedTransfer('PUT', url, headers: headers, bytes: bytes);
    }
    requireWorkspace(workspace);
    final completeKey = await keys.acquire('$signature:complete', {
      'attachmentId': attachmentId,
    });
    await command('$base/complete', key: completeKey);
    await keys.clear('$signature:presign');
    await keys.clear('$signature:complete');
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
    final downloadUrl = requiredText(file, 'downloadUrl');
    final path = '/requests/${record.id}/attachments/${attachment['id']}/file';
    if (downloadUrl.startsWith('/')) {
      if (record.kind != 'request' || downloadUrl != '/api/v1$path') {
        throw const DataFailure(
          0,
          'INVALID_FILE_URL',
          'The download link does not match this private attachment.',
        );
      }
      final result = await client.request(
        DataRequest('GET', path, responseType: 'bytes'),
      );
      requireWorkspace(workspace);
      return result.data as Uint8List;
    }
    final bytes = await signedTransfer('GET', fileUrl(downloadUrl));
    requireWorkspace(workspace);
    return bytes;
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
        !trustedOrigins.contains(u.origin)) {
      throw const DataFailure(
        0,
        'INVALID_FILE_URL',
        'The signed file URL is outside the configured storage origins.',
      );
    }
    return u;
  }
}
