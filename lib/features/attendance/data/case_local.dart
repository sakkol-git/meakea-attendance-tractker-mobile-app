part of '../../../core/demo/local_service.dart';

extension AttendanceCases on LocalDataSource {
  String _sessionDay(JsonMap s) =>
      s['workDate'] as String? ??
      DateTime.parse(s['checkInAt'] ?? s['clockIn'])
          .toUtc()
          .add(const Duration(hours: 7))
          .toIso8601String()
          .substring(0, 10);
  List<JsonMap> _dailyRows(DataRequest r, {bool own = false}) {
    final from = r.query['from'] ?? today;
    final to = r.query['to'] ?? today;
    _need(
      _validDate(from) && _validDate(to),
      'VALIDATION_ERROR',
      'Choose valid report dates.',
    );
    final start = DateTime.parse(from), end = DateTime.parse(to);
    _need(
      !end.isBefore(start) && end.difference(start).inDays <= 366,
      'VALIDATION_ERROR',
      'Choose a period of at most one year.',
    );
    final result = <JsonMap>[];
    for (final person in _table('/employees')) {
      final id = person['id'] as String;
      if (own ? id != employeeId : !_visible({'employeeId': id})) continue;
      for (
        var day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))
      ) {
        final date = day.toIso8601String().substring(0, 10);
        final candidates = _sessions
            .where(
              (s) =>
                  s['employeeId'] == id &&
                  s['supersededBy'] == null &&
                  s['confirmStatus'] != 'REJECTED' &&
                  _sessionDay(s) == date,
            )
            .toList();
        final manual = candidates
            .where((s) => s['source'] == 'MANUAL')
            .toList();
        final taps = candidates.where((s) => s['source'] == 'TAP').toList();
        final sessions = manual.isNotEmpty
            ? manual
            : taps.isNotEmpty
            ? taps
            : candidates;
        final shift = _assignedShift(id, date);
        final holiday = _table('/holidays')
            .any((v) => v['date'] == date && v['status'] != 'ARCHIVED');
        final leave = _table('/leave/requests').any(
          (v) =>
              v['employeeId'] == id &&
              v['status'] == 'APPROVED' &&
              (v['startDate'] as String).compareTo(date) <= 0 &&
              (v['endDate'] as String).compareTo(date) >= 0,
        );
        final workingDays = shift?['workingDays'] as int? ?? 31;
        final off =
            shift != null && (workingDays & (1 << (day.weekday - 1))) == 0;
        var worked = 0, late = 0, early = 0;
        for (final s in sessions) {
          final a = DateTime.parse(s['checkInAt'] ?? s['clockIn']);
          final b = DateTime.tryParse(s['checkOutAt'] ?? s['clockOut'] ?? '');
          if (b != null && b.isAfter(a)) worked += b.difference(a).inMinutes;
        }
        final ordered = [...sessions]
          ..sort(
            (a, b) => (a['checkInAt'] ?? a['clockIn']).toString().compareTo(
              (b['checkInAt'] ?? b['clockIn']).toString(),
            ),
          );
        if (shift != null && ordered.isNotEmpty) {
          final expected = DateTime.parse(
            '${date}T${shift['startTime']}:00+07:00',
          );
          final first = DateTime.parse(
            ordered.first['checkInAt'] ?? ordered.first['clockIn'],
          );
          if (first.isAfter(
            expected.add(
              Duration(minutes: (shift['graceMinutes'] as num? ?? 10).toInt()),
            ),
          )) {
            late = (first.difference(expected).inSeconds / 60).ceil();
          }
          var finish = DateTime.parse('${date}T${shift['endTime']}:00+07:00');
          if (!finish.isAfter(expected)) {
            finish = finish.add(const Duration(days: 1));
          }
          final ends =
              ordered
                  .map(
                    (s) => DateTime.tryParse(
                      s['checkOutAt'] ?? s['clockOut'] ?? '',
                    ),
                  )
                  .whereType<DateTime>()
                  .toList()
                ..sort();
          if (ends.isNotEmpty) {
            if (ends.last.isBefore(
              finish.subtract(
                Duration(
                  minutes: (shift['earlyToleranceMinutes'] as num? ?? 0)
                      .toInt(),
                ),
              ),
            )) {
              early = (finish.difference(ends.last).inSeconds / 60).ceil();
            }
          }
        }
        final revision = int.parse(
          sha256
              .convert(
                utf8.encode(
                  canonicalJson({
                    'sessions': _sessions
                        .where(
                          (s) =>
                              s['employeeId'] == id && _sessionDay(s) == date,
                        )
                        .toList(),
                    'shift': shift,
                    'leave': _table('/leave/requests')
                        .where(
                          (s) =>
                              s['employeeId'] == id &&
                              (s['startDate'] as String).compareTo(date) <= 0 &&
                              (s['endDate'] as String).compareTo(date) >= 0,
                        )
                        .toList(),
                    'holidays': _table('/holidays')
                        .where((h) => h['date'] == date)
                        .toList(),
                  }),
                ),
              )
              .toString()
              .substring(0, 12),
          radix: 16,
        );
        final rowId = '$id--$date';
        final finalization = _table('/attendance/finalized')
            .where((v) => v['id'] == rowId && v['version'] == revision)
            .firstOrNull;
        result.add({
          'id': rowId,
          'title': '${person['name']} · $date',
          'employeeId': id,
          'employeeName': person['name'],
          'workDate': date,
          'dayStatus': holiday
              ? 'HOLIDAY'
              : off
              ? 'DAY_OFF'
              : leave
              ? 'LEAVE'
              : sessions.isNotEmpty
              ? 'PRESENT'
              : shift == null
              ? 'UNSCHEDULED'
              : 'ABSENT',
          'status': finalization == null ? 'PROVISIONAL' : 'FINALIZED',
          'workedMinutes': worked,
          'lateMinutes': late,
          'earlyMinutes': early,
          'source': sessions.map((s) => s['source']).toSet().join(', '),
          'finalized': finalization != null,
          'version': revision,
          'openSessions': sessions
              .where((s) => (s['checkOutAt'] ?? s['clockOut']) == null)
              .length,
          'pendingConfirmation': sessions.any(
            (s) => s['confirmStatus'] == 'PENDING',
          ),
        });
      }
    }
    return result;
  }

  DataResponse? _attendanceCases(DataRequest r) {
    final b = r.body ?? {};
    if (r.path == '/attendance/work-sites/me' && r.method == 'GET') {
      return _page(
        _table('/work-sites').where((s) => s['status'] != 'ARCHIVED'),
        r,
      );
    }
    if (r.method == 'GET' &&
        [
          '/attendance/daily-status/me',
          '/attendance/daily-status',
          '/attendance/reviews',
        ].contains(r.path)) {
      final own = r.path.endsWith('/me');
      _need(
        own || _manages,
        'FORBIDDEN',
        'Management access is required.',
        status: 403,
      );
      if (r.path.endsWith('/reviews')) {
        _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      }
      return _page(_dailyRows(r, own: own), r);
    }
    if (r.path == '/attendance/manual' && r.method == 'GET') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      return _page(_sessions.where((s) => s['source'] == 'MANUAL'), r);
    }
    if (r.path == '/attendance/manual' && r.method == 'POST') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      final id = b['employeeId'] as String? ?? '';
      _person(id);
      _need(
        id != employeeId,
        'SELF_APPROVAL',
        'A different HR reviewer must enter your attendance.',
        status: 403,
      );
      _reason(b);
      _need(
        _validDate(b['workDate']) &&
            RegExp(r'^([01]\d|2[0-3]):[0-5]\d$')
                .hasMatch(b['checkIn']?.toString() ?? '') &&
            RegExp(r'^([01]\d|2[0-3]):[0-5]\d$')
                .hasMatch(b['checkOut']?.toString() ?? ''),
        'VALIDATION_ERROR',
        'Choose a valid day and clock times.',
      );
      final a = DateTime.parse("${b['workDate']}T${b['checkIn']}:00+07:00");
      var z = DateTime.parse("${b['workDate']}T${b['checkOut']}:00+07:00");
      if (z.isBefore(a)) z = z.add(const Duration(days: 1));
      _need(
        z.isAfter(a) && z.difference(a).inHours < 24,
        'VALIDATION_ERROR',
        'The interval must be greater than zero and less than 24 hours.',
      );
      final row = <String, dynamic>{
        'id': _id(),
        'employeeId': id,
        'employeeName': _employeeName(id),
        'workDate': b['workDate'],
        'checkInAt': a.toUtc().toIso8601String(),
        'checkOutAt': z.toUtc().toIso8601String(),
        'reason': b['reason'],
        'source': 'MANUAL',
        'confirmStatus': 'NONE',
        'version': 1,
      };
      for (final s in _sessions.where(
        (s) =>
            s['employeeId'] == id &&
            _sessionDay(s) == b['workDate'] &&
            s['supersededBy'] == null,
      )) {
        s['supersededBy'] = row['id'];
        s['version']++;
      }
      _sessions.add(row);
      _detectLeaveConflict(row);
      _auditAction('MANUAL_ATTENDANCE', row['id']);
      return _ok(row, status: 201, etag: '"1"');
    }
    if (r.path == '/attendance/evidence/me' && r.method == 'GET') {
      return _page(
        _table('/attendance/evidence')
            .where((v) => v['employeeId'] == employeeId),
        r,
      );
    }
    if (r.path == '/attendance/evidence' && r.method == 'POST') {
      final batch = b['items'] as List? ?? [];
      _need(
        batch.length == 1,
        'VALIDATION_ERROR',
        'Submit one reviewed site transition.',
      );
      final event = JsonMap.from(batch.single as Map);
      final accuracy = event['accuracyM'];
      _need(
        accuracy is num &&
            accuracy >= 0 &&
            accuracy.isFinite &&
            ['GEOFENCE_ENTER', 'GEOFENCE_EXIT'].contains(event['kind']),
        'VALIDATION_ERROR',
        'Submit a valid work-site transition and accuracy.',
      );
      final site = _find(
        '/work-sites',
        (event['payload'] as Map?)?['siteId'] as String? ?? '',
      );
      _need(
        site['status'] != 'ARCHIVED',
        'SITE_UNAVAILABLE',
        'This work site is no longer available.',
        status: 409,
      );
      final row = <String, dynamic>{
        'id': _id(),
        'title': 'Attendance observation',
        'employeeId': employeeId,
        'workDate': today,
        'capturedAt': event['occurredAt'],
        'kind': event['kind'],
        'siteName': site['name'],
        'accuracyMeters': accuracy,
        'status': 'RECEIVED',
        'decision': 'NO_ACTION',
        'message': 'Observation saved in the demo. A production scoring service must evaluate the evidence; attendance is unchanged.',
        'version': 1,
      };
      _table('/attendance/evidence').add(row);
      return _ok(row, status: 202);
    }
    final match = RegExp(r'^/attendance/daily-status/([^/]+)/finalize$')
        .firstMatch(r.path);
    if (match != null && r.method == 'POST') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      _reason(b);
      final parts = match[1]!.split('--');
      _need(parts.length == 2, 'NOT_FOUND', 'Day not found.', status: 404);
      final rows = _dailyRows(
        DataRequest(
          'GET',
          '/attendance/daily-status',
          query: {'from': parts.last, 'to': parts.last},
        ),
      );
      final row = rows.where((v) => v['id'] == match[1]).firstOrNull;
      _need(row != null, 'NOT_FOUND', 'Day not found.', status: 404);
      _version(r, row!);
      _need(
        row['employeeId'] != employeeId,
        'SELF_APPROVAL',
        'Another HR reviewer must finalize your attendance.',
        status: 403,
      );
      _need(
        row['openSessions'] == 0 && row['pendingConfirmation'] == false,
        'REVIEW_REQUIRED',
        'Close open sessions and resolve inferred attendance before finalizing.',
        status: 409,
      );
      _need(
        !_table('/leave/conflicts').any(
          (v) =>
              v['employeeId'] == row['employeeId'] &&
              v['status'] == 'NEEDS_REVIEW',
        ),
        'LEAVE_CONFLICT',
        'Resolve outstanding leave conflicts first.',
        status: 409,
      );
      _table('/attendance/finalized').removeWhere((v) => v['id'] == row['id']);
      _table('/attendance/finalized').add({
        ...row,
        'reason': b['reason'],
        'finalized': true,
        'status': 'FINALIZED',
      });
      _auditAction('ATTENDANCE_FINALIZED', row['id']);
      return _ok({
        ...row,
        'finalized': true,
        'status': 'FINALIZED',
      }, etag: '"${row['version']}"');
    }
    return null;
  }
}
