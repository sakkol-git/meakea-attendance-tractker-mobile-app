import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/data/json.dart';
import 'package:hrflow_mobile/core/data/resource_repository.dart';
import 'package:hrflow_mobile/features/attachments/data/methods.dart';

mixin ReportingMethods on ResourceRepository, AttachmentsMethods {
  Future<({String name, Uint8List bytes})> exportAttendance(String key) async {
    final workspace = client.workspaceRevision;
    final job = object(
      (await command(
        '/reports/exports',
        body: {'report': 'ATTENDANCE', 'format': 'CSV'},
        key: key,
      )).data,
    );
    var current = job;
    for (
      var attempt = 0;
      attempt < 10 &&
          ['QUEUED', 'RUNNING', 'PENDING'].contains(current['status']);
      attempt++
    ) {
      await Future<void>.delayed(const Duration(seconds: 2));
      requireWorkspace(workspace);
      current = object(
        await get('/reports/exports/${requiredText(job, 'id')}'),
      );
    }
    if (['FAILED', 'CANCELLED'].contains(current['status'])) {
      throw const DataFailure(
        0,
        'EXPORT_FAILED',
        'The export failed. Start a new export.',
      );
    }
    if (current['status'] != 'COMPLETED') {
      throw const DataFailure(
        0,
        'EXPORT_PENDING',
        'The export is not complete. Check again later.',
      );
    }
    return _downloadCompleted(current, workspace);
  }

  Future<({String name, Uint8List bytes})> downloadExport(String id) async {
    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(id)) {
      throw const DataFailure(422, 'INVALID_EXPORT', 'Select a valid export.');
    }
    final workspace = client.workspaceRevision;
    final current = object(await get('/reports/exports/$id'));
    if (current['status'] != 'COMPLETED') {
      throw const DataFailure(
        409,
        'EXPORT_PENDING',
        'This export is not complete. Refresh its status.',
      );
    }
    return _downloadCompleted(current, workspace);
  }

  Future<({String name, Uint8List bytes})> _downloadCompleted(
    JsonMap current,
    int workspace,
  ) async {
    requireWorkspace(workspace);
    if (client.isLocal) {
      return (
        name: current['fileName'] as String,
        bytes: Uint8List.fromList(
          utf8.encode(requiredText(current, 'content')),
        ),
      );
    }
    final response = await http
        .get(fileUrl(requiredText(current, 'downloadUrl')))
        .timeout(const Duration(seconds: 60));
    if (response.statusCode != 200) {
      throw const DataFailure(
        0,
        'DOWNLOAD_FAILED',
        'Could not download the export.',
      );
    }
    requireWorkspace(workspace);
    return (
      name: current['fileName'] as String? ?? 'attendance.csv',
      bytes: response.bodyBytes,
    );
  }
}
