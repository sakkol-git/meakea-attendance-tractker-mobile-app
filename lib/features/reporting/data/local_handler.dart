part of '../../../core/demo/local_service.dart';

extension ReportingDemo on LocalDataSource {
  DataResponse? _handleReporting(DataRequest r) {
    final caseResult = _reportingCases(r);
    if (caseResult != null) return caseResult;
    final body = r.body ?? {};
    if (r.path.startsWith('/reports/') && r.method == 'GET') {
      _need(
        _manages,
        'FORBIDDEN',
        'Management access is required.',
        status: 403,
      );
      if (r.path.startsWith('/reports/exports/')) {
        final row = _rows['/exports']!
            .where(
              (e) =>
                  e['id'] == r.path.split('/').last &&
                  e['employeeId'] == employeeId,
            )
            .firstOrNull;
        _need(row != null, 'NOT_FOUND', 'Export not found.', status: 404);
        return _ok(row);
      }
      return _ok({
        'employees': _table('/employees')
            .where((p) => _visible({'employeeId': p['id']}))
            .length,
        'attendanceSessions': _sessions
            .where(
              (s) =>
                  _visible(s) &&
                  s['supersededBy'] == null &&
                  s['confirmStatus'] != 'REJECTED',
            )
            .length,
        'pendingLeave': _rows['/leave/requests']!
            .where((r) => _visible(r) && r['status'] == 'PENDING')
            .length,
        'pendingRequests': _rows['/requests']!
            .where((r) => _visible(r) && r['status'] == 'PENDING')
            .length,
        'items': _sessions.where(_visible).toList(),
      });
    }
    if (r.path == '/reports/exports' && r.method == 'POST') {
      _need(
        _manages,
        'FORBIDDEN',
        'Management access is required.',
        status: 403,
      );
      final report = body['report'] as String? ?? 'ATTENDANCE';
      _need(
        ['ATTENDANCE', 'LEAVE', 'REQUESTS'].contains(report) &&
            body['format'] == 'CSV',
        'INVALID_REPORT',
        'Choose an available CSV report.',
      );
      _need(
        (body['from'] == null && body['to'] == null) ||
            (_validDate(body['from']) &&
                _validDate(body['to']) &&
                (body['to'] as String).compareTo(body['from']) >= 0),
        'VALIDATION_ERROR',
        'Choose a valid report period.',
      );
      final query = <String, String>{
        if (body['from'] != null) 'from': body['from'],
        if (body['to'] != null) 'to': body['to'],
      };
      final data = _reportRows(
        report.toLowerCase(),
        DataRequest('GET', '/reports/export', query: query),
      );
      final columns = switch (report) {
        'LEAVE' => ['employeeName', 'approvedDays', 'pendingDays'],
        'REQUESTS' => ['employeeName', 'pending', 'approved', 'fulfilled'],
        _ => [
          'employeeName',
          'sessions',
          'workedMinutes',
          'lateDays',
          'absentDays',
        ],
      };
      String cell(Object? v) {
        var value = v?.toString() ?? '';
        if (RegExp(r'^[=+@\-\t\r]').hasMatch(value)) value = "'$value";
        return '"${value.replaceAll('"', '""')}"';
      }

      final csv = StringBuffer('${columns.join(',')}\r\n');
      for (final row in data) {
        csv.writeln(columns.map((key) => cell(row[key])).join(','));
      }
      final row = <String, dynamic>{
        'id': _id(),
        'status': 'COMPLETED',
        'fileName': '${report.toLowerCase()}.csv',
        'title': '${report.toLowerCase()} export',
        'report': report,
        'format': 'CSV',
        'employeeId': employeeId,
        'createdAt': _now().toUtc().toIso8601String(),
        'version': 1,
        'content': csv.toString(),
      };
      _rows['/exports']!.add(row);
      return _ok(row, status: 202);
    }
    return null;
  }
}
