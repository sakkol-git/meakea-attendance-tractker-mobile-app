part of '../../../core/demo/local_service.dart';

extension ReportingCases on LocalDataSource {
  List<JsonMap> _reportRows(String report, DataRequest r) {
    final people = _table('/employees')
        .where((v) => _visible({'employeeId': v['id']}));
    final result = <JsonMap>[];
    if (report == 'balances') {
      for (final p in people) {
        result.addAll(_leaveBalancesFor(p['id'], _companyNow.year));
      }
      return result;
    }
    for (final p in people) {
      final id = p['id'];
      final sessions = _sessions
          .where(
            (v) =>
                v['employeeId'] == id &&
                v['supersededBy'] == null &&
                v['confirmStatus'] != 'REJECTED',
          )
          .where((v) {
            final d = _sessionDay(v);
            return (r.query['from'] == null ||
                    d.compareTo(r.query['from']!) >= 0) &&
                (r.query['to'] == null || d.compareTo(r.query['to']!) <= 0);
          })
          .toList();
      final leaves = _table('/leave/requests').where(
        (v) =>
            v['employeeId'] == id &&
            (r.query['from'] == null ||
                (v['endDate'] as String).compareTo(r.query['from']!) >= 0) &&
            (r.query['to'] == null ||
                (v['startDate'] as String).compareTo(r.query['to']!) <= 0),
      );
      final requests = _table('/requests').where((v) => v['employeeId'] == id);
      final daily = _dailyRows(r).where((v) => v['employeeId'] == id);
      var minutes = 0;
      for (final s in sessions) {
        final a = DateTime.parse(s['checkInAt'] ?? s['clockIn']);
        final b = DateTime.tryParse(s['checkOutAt'] ?? s['clockOut'] ?? '');
        if (b != null && b.isAfter(a)) minutes += b.difference(a).inMinutes;
      }
      num leaveDays(JsonMap row) {
        final portions = row['dayPortions'];
        if (portions is! List) return row['days'] as num? ?? 0;
        return portions
                .where(
                  (p) =>
                      (r.query['from'] == null ||
                          (p['date'] as String).compareTo(r.query['from']!) >=
                              0) &&
                      (r.query['to'] == null ||
                          (p['date'] as String).compareTo(r.query['to']!) <= 0),
                )
                .fold<int>(0, (n, p) => n + (p['units'] as int)) /
            100;
      }

      result.add({
        'id': '$report--$id',
        'title': p['name'],
        'employeeName': p['name'],
        'status': 'CURRENT',
        'sessions': sessions.length,
        'workedMinutes': minutes,
        'lateDays': daily.where((v) => (v['lateMinutes'] as int) > 0).length,
        'lateMinutes': daily.fold<int>(
          0,
          (n, v) => n + (v['lateMinutes'] as int),
        ),
        'absentDays': daily.where((v) => v['dayStatus'] == 'ABSENT').length,
        'approvedDays': leaves
            .where((v) => v['status'] == 'APPROVED')
            .fold<num>(0, (n, v) => n + leaveDays(v)),
        'pendingDays': leaves
            .where((v) => v['status'] == 'PENDING')
            .fold<num>(0, (n, v) => n + leaveDays(v)),
        'pending': requests.where((v) => v['status'] == 'PENDING').length,
        'approved': requests.where((v) => v['status'] == 'APPROVED').length,
        'fulfilled': requests.where((v) => v['status'] == 'FULFILLED').length,
        'asOf': _now().toUtc().toIso8601String(),
        'version': 1,
      });
    }
    return result;
  }

  DataResponse? _reportingCases(DataRequest r) {
    const routes = {
      '/reports/attendance/summary': 'attendance',
      '/reports/attendance/late-ranking': 'late',
      '/reports/leave/summary': 'leave',
      '/reports/leave/balances': 'balances',
      '/reports/requests/summary': 'requests',
    };
    if (routes.containsKey(r.path) && r.method == 'GET') {
      _need(
        _manages,
        'FORBIDDEN',
        'Management access is required.',
        status: 403,
      );
      if (routes[r.path] == 'balances') {
        _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      }
      return _page(_reportRows(routes[r.path]!, r), r);
    }
    if (r.path == '/reports/exports' && r.method == 'GET') {
      _need(
        _manages,
        'FORBIDDEN',
        'Management access is required.',
        status: 403,
      );
      return _page(
        _table('/exports').where((v) => v['employeeId'] == employeeId),
        r,
      );
    }
    if (r.path == '/reports/admin/rebuilds') {
      _need(
        _actor == 'OWNER',
        'FORBIDDEN',
        'Owner access is required.',
        status: 403,
      );
      if (r.method == 'GET') return _page(_table('/report-rebuilds'), r);
      if (r.method == 'POST') {
        _reason(r.body ?? {});
        final row = <String, dynamic>{
          'id': _id(),
          'title': 'Report recovery',
          'status': 'COMPLETED',
          'reason': r.body!['reason'],
          'createdAt': _now().toIso8601String(),
          'completedAt': _now().toIso8601String(),
          'message': 'Local reports read the current demo source records. No production projection or worker was rebuilt.',
          'version': 1,
        };
        _table('/report-rebuilds').add(row);
        _auditAction('REPORT_REBUILD', row['id']);
        return _ok(row, status: 202);
      }
    }
    return null;
  }
}
