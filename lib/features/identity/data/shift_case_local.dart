part of '../../../core/demo/local_service.dart';

extension IdentityShiftCaseDemo on LocalDataSource {
  DataResponse? _shiftCase(DataRequest r) {
    final body = r.body ?? {};
    if ((r.path == '/shifts' && r.method == 'POST') ||
        (RegExp(r'^/shifts/[^/]+$').hasMatch(r.path) && r.method == 'PATCH')) {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      _need(
        body.keys.every(
          {
            'name',
            'startTime',
            'endTime',
            'workingDays',
            'graceMinutes',
            'siteId',
            'timezone',
            'earlyToleranceMinutes',
            'reason',
          }.contains,
        ),
        'VALIDATION_ERROR',
        'The shift edit contains an unsupported field.',
      );
      final row = r.method == 'POST'
          ? <String, dynamic>{'id': _id(), 'version': 0}
          : _find('/shifts', r.path.split('/').last);
      if (r.method == 'PATCH') _version(r, row);
      final merged = <String, dynamic>{...row, ...body};
      final time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
      _need(
        (merged['name'] as String? ?? '').trim().length >= 3 &&
            time.hasMatch(merged['startTime'] as String? ?? '') &&
            time.hasMatch(merged['endTime'] as String? ?? '') &&
            (merged['endTime'] as String).compareTo(
                  merged['startTime'] as String,
                ) >
                0,
        'VALIDATION_ERROR',
        'Enter a name and same-day shift with end after start.',
      );
      final days = merged['workingDays'] ?? 31,
          grace = merged['graceMinutes'] ?? 10,
          siteId = merged['siteId'] ?? 'site-headquarters',
          early = merged['earlyToleranceMinutes'] ?? 0;
      final site = _table('/work-sites')
          .where((row) => row['id'] == siteId)
          .firstOrNull;
      _need(
        days is int &&
            days > 0 &&
            days <= 127 &&
            grace is num &&
            grace >= 0 &&
            grace <= 120 &&
            early is num &&
            early >= 0 &&
            early <= 120 &&
            site != null &&
            site['status'] != 'ARCHIVED' &&
            (merged['timezone'] ?? site['timezone']) == site['timezone'],
        'VALIDATION_ERROR',
        'Choose workdays and valid grace periods.',
      );
      row.addAll({
        'name': merged['name'],
        'startTime': merged['startTime'],
        'endTime': merged['endTime'],
        'workingDays': days,
        'graceMinutes': grace,
        'siteId': siteId,
        'timezone': merged['timezone'] ?? site?['timezone'],
        'earlyToleranceMinutes': early,
        if (body['reason'] != null) 'lastChangeReason': body['reason'],
        'days': [
          for (var i = 0; i < 7; i++)
            if ((days & (1 << i)) != 0)
              const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i],
        ].join(', '),
        'version': (row['version'] as int) + 1,
      });
      if (r.method == 'POST') _table('/shifts').add(row);
      _auditAction('SHIFT_POLICY_UPDATED', row['id']);
      return _ok(
        row,
        etag: '"${row['version']}"',
        status: r.method == 'POST' ? 201 : 200,
      );
    }

    return null;
  }
}
