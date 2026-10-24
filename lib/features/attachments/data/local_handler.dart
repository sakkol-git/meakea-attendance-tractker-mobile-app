part of '../../../core/demo/local_service.dart';

extension AttachmentsDemo on LocalDataSource {
  DataResponse? _handleAttachments(DataRequest r) {
    final body = r.body ?? {};
    final fileMatch = RegExp(
      r'^/(requests|leave/requests)/([^/]+)/attachments(?:/([^/]+))?$',
    ).firstMatch(r.path);
    if (fileMatch != null) {
      final row = _table('/${fileMatch[1]}')
          .where((v) => v['id'] == fileMatch[2] && _visible(v))
          .firstOrNull;
      _need(row != null, 'NOT_FOUND', 'Request not found.', status: 404);
      if (r.method == 'POST') {
        _need(
          row!['employeeId'] == employeeId,
          'FORBIDDEN',
          'Only the request owner can add files.',
          status: 403,
        );
        _need(
          ['DRAFT', 'PENDING'].contains(row['status']),
          'INVALID_TRANSITION',
          'Files can only be added before the review is complete.',
          status: 409,
        );
        final bytes = base64Decode(body['content'] as String? ?? '');
        _need(
          bytes.isNotEmpty &&
              bytes.length <= 10 * 1024 * 1024 &&
              body['size'] == bytes.length,
          'INVALID_FILE',
          'Choose a nonempty file of at most 10 MB.',
        );
        _need(
          (body['name'] as String? ?? '').trim().isNotEmpty &&
              !(body['name'] as String).contains('/'),
          'INVALID_FILE',
          'Choose a valid filename.',
        );
        _need(
          _files.values.fold<int>(0, (n, f) => n + (f['size'] as int? ?? 0)) +
                  bytes.length <=
              20 * 1024 * 1024,
          'DEMO_STORAGE_FULL',
          'The demo file limit is 20 MB. Reset demo data or use smaller files.',
        );
        final file = <String, dynamic>{
          ...body,
          'id': _id(),
          'recordId': row['id'],
        };
        _files[file['id']] = file;
        (row['attachments'] as List? ?? (row['attachments'] = [])).add({
          'id': file['id'],
          'name': body['name'],
          'size': body['size'],
        });
        return _ok(file, status: 201);
      }
      if (r.method == 'GET') {
        final file = _files[fileMatch[3]];
        _need(
          file != null &&
              (row!['attachments'] as List? ?? []).any(
                (v) => v['id'] == fileMatch[3],
              ),
          'NOT_FOUND',
          'Attachment not found.',
          status: 404,
        );
        return _ok(file);
      }
    }
    return null;
  }
}
