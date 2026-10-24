part of '../../../core/demo/local_service.dart';

extension AttendanceDemo on LocalDataSource {
  List<JsonMap> _orderedSessions(Iterable<JsonMap> sessions) =>
      sessions.toList()..sort(
        (a, b) =>
            DateTime.parse(b['checkInAt'] ?? b['clockIn'])
                .compareTo(DateTime.parse(a['checkInAt'] ?? a['clockIn'])),
      );
  void _validateAttendance(String path, JsonMap body) {
    final start = DateTime.tryParse(body['newCheckIn'] as String? ?? '');
    final end = DateTime.tryParse(body['newCheckOut'] as String? ?? '');
    final day = DateTime.tryParse(body['workDate'] as String? ?? '');
    _need(
      start != null &&
          end != null &&
          day != null &&
          end.isAfter(start) &&
          end.difference(start) <= const Duration(hours: 24),
      'VALIDATION_ERROR',
      'Provide a valid correction of at most 24 hours.',
    );
    _need(
      start!
              .toUtc()
              .add(const Duration(hours: 7))
              .toIso8601String()
              .substring(0, 10) ==
          body['workDate'],
      'VALIDATION_ERROR',
      'The correction must begin on the affected workday.',
    );
  }

  DataResponse? _handleAttendance(DataRequest r) {
    final caseResult = _attendanceCases(r);
    if (caseResult != null) return caseResult;
    if (r.path == '/attendance/today' && r.method == 'GET') {
      return _ok({
        'date': today,
        'workDate': today,
        'shift': populate
            ? _assignedShift(employeeId, today)
            : _rows['/shifts']!.firstOrNull,
        'sessions': _own(_sessions)
            .where(
              (s) =>
                  DateTime.parse(
                        s['checkInAt'] as String? ?? s['clockIn'] as String,
                      )
                      .toUtc()
                      .add(const Duration(hours: 7))
                      .toIso8601String()
                      .startsWith(today),
            )
            .toList(),
      });
    }
    if (r.path == '/attendance/me' && r.method == 'GET') {
      return _page(_orderedSessions(_own(_sessions)), r);
    }
    if (r.path == '/attendance/team' && r.method == 'GET') {
      _need(
        _manages,
        'FORBIDDEN',
        'Management access is required.',
        status: 403,
      );
      return _page(_orderedSessions(_sessions.where(_visible)), r);
    }
    if (r.method == 'POST' &&
        ['/attendance/check-in', '/attendance/check-out'].contains(r.path)) {
      final open = _own(_sessions)
          .where(
            (v) =>
                v['confirmStatus'] != 'REJECTED' &&
                (v['checkOutAt'] ?? v['clockOut']) == null,
          )
          .firstOrNull;
      if (r.path.endsWith('check-in')) {
        _need(
          open == null,
          'SESSION_ALREADY_OPEN',
          'Clock out before starting another session.',
          status: 409,
        );
        final stamp = _now().toUtc().toIso8601String();
        final row = <String, dynamic>{
          'id': _id(),
          'employeeId': employeeId,
          'clockIn': stamp,
          'checkInAt': stamp,
          'clockOut': null,
          'checkOutAt': null,
          'workDate': today,
          'version': 1,
          'source': 'TAP',
          'confirmStatus': 'NONE',
        };
        _sessions.add(row);
        _detectLeaveConflict(row);
        _auditAction('CLOCK_IN', row['id']);
        return _ok(row, status: 201, etag: '"1"');
      }
      _need(
        open != null,
        'NO_OPEN_SESSION',
        'Clock in before clocking out.',
        status: 409,
      );
      _version(r, open!);
      open['clockOut'] = open['checkOutAt'] = _now().toUtc().toIso8601String();
      open['version'] = (open['version'] as int) + 1;
      _auditAction('CLOCK_OUT', open['id']);
      return _ok(open, etag: '"${open['version']}"');
    }
    final sessionMatch = RegExp(
      r'^/attendance/sessions/([^/]+)/(confirm|reject)$',
    ).firstMatch(r.path);
    if (sessionMatch != null && r.method == 'POST') {
      final row = _own(_sessions)
          .where((s) => s['id'] == sessionMatch[1])
          .firstOrNull;
      _need(row != null, 'NOT_FOUND', 'Session not found.', status: 404);
      _version(r, row!);
      _need(
        row['confirmStatus'] == 'PENDING',
        'INVALID_TRANSITION',
        'This record no longer needs confirmation.',
        status: 409,
      );
      row['confirmStatus'] = sessionMatch[2] == 'confirm'
          ? 'CONFIRMED'
          : 'REJECTED';
      row['version']++;
      return _ok(row, etag: '"${row['version']}"');
    }
    return null;
  }
}
