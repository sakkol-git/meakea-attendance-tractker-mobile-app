part of '../../../core/demo/local_service.dart';

extension LeaveCasesDemo on LocalDataSource {
  int _requestUnits(JsonMap row, int year) {
    final portions = row['dayPortions'];
    if (portions is List) {
      return portions
          .where((p) => (p['date'] as String).startsWith('$year-'))
          .fold<int>(0, (sum, p) => sum + (p['units'] as int));
    }
    return (row['startDate'] as String? ?? '').startsWith('$year-')
        ? _units(row['days'] ?? 0)
        : 0;
  }

  List<JsonMap> _leaveBalancesFor(String person, int year) =>
      _table('/leave/types')
          .where((type) => type['status'] != 'ARCHIVED')
          .map((type) {
            final requests = _table('/leave/requests').where(
              (r) =>
                  r['employeeId'] == person && r['leaveTypeId'] == type['id'],
            );
            final ledger = _table('/leave/ledger').where(
              (r) =>
                  r['employeeId'] == person &&
                  r['leaveTypeId'] == type['id'] &&
                  r['year'] == year,
            );
            final entitled =
                _units(type['annualDays'] ?? type['entitled'] ?? 0) +
                ledger
                    .where((r) => r['kind'] == 'ADJUST')
                    .fold<int>(0, (v, r) => v + (r['units'] as int));
            final carry = ledger
                .where((r) => r['kind'] == 'ROLLOVER')
                .fold<int>(0, (v, r) => v + (r['units'] as int));
            final used = requests
                .where((r) => r['status'] == 'APPROVED')
                .fold<int>(0, (v, r) => v + _requestUnits(r, year));
            final pending = requests
                .where((r) => r['status'] == 'PENDING')
                .fold<int>(0, (v, r) => v + _requestUnits(r, year));
            final revision =
                (type['version'] as int? ?? 1) +
                requests
                    .where((r) => _requestUnits(r, year) > 0)
                    .fold<int>(0, (v, r) => v + (r['version'] as int)) +
                ledger.length;
            return <String, dynamic>{
              'id': '$person--${type['id']}--$year',
              'employeeId': person,
              'employeeName': _employeeName(person),
              'leaveTypeId': type['id'],
              'name': type['name'],
              'typeName': type['name'],
              'year': year,
              'entitled': entitled / 100,
              'carriedOver': carry / 100,
              'used': used / 100,
              'pending': pending / 100,
              'available': (entitled + carry - used - pending) / 100,
              'version': revision,
              'etag': '"$revision"',
              'status': 'CURRENT',
            };
          })
          .toList();
  void _leaveEntry(
    JsonMap row,
    String kind, {
    int? units,
    int? year,
    String? reason,
  }) {
    final years = year == null
        ? {
            for (final p in row['dayPortions'] as List? ?? [])
              int.parse((p['date'] as String).substring(0, 4)),
          }
        : {year};
    if (years.isEmpty) {
      years.add(int.parse((row['startDate'] as String).substring(0, 4)));
    }
    for (final y in years) {
      final quantity = units ?? _requestUnits(row, y);
      if (quantity == 0) continue;
      _table('/leave/ledger').insert(0, {
        'id': _id(),
        'employeeId': row['employeeId'],
        'employeeName': _employeeName(row['employeeId']),
        'leaveTypeId': row['leaveTypeId'],
        'typeName':
            _table('/leave/types')
                .where((t) => t['id'] == row['leaveTypeId'])
                .firstOrNull?['name'] ??
            'Leave',
        'year': y,
        'kind': kind,
        'units': quantity,
        'days': quantity / 100,
        'reason': reason ?? row['reason'] ?? 'Leave workflow update',
        'requestId': row['id'],
        'createdAt': _now().toUtc().toIso8601String(),
        'version': 1,
        'status': 'RECORDED',
      });
    }
  }

  String _rolloverBasis(int fromYear) => canonicalJson([
    for (final p in _table('/employees').where((p) => p['status'] == 'ACTIVE'))
      ..._leaveBalancesFor(p['id'], fromYear).map(
        (b) => {
          'id': b['id'],
          'version': b['version'],
          'available': b['available'],
        },
      ),
  ]);
  DataResponse? _leaveCases(DataRequest r) {
    final body = r.body ?? {};
    if (r.path == '/leave/calendar' && r.method == 'GET') {
      return _page(
        _table('/leave/requests').where(
          (row) =>
              _visible(row) && ['PENDING', 'APPROVED'].contains(row['status']),
        ),
        r,
      );
    }
    if (r.path == '/leave/admin/types' && r.method == 'GET') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      return _page(_table('/leave/types'), r);
    }
    if (r.path == '/leave/admin/balances' && r.method == 'GET') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      final year = int.tryParse(r.query['year'] ?? '') ?? _companyNow.year;
      return _page([
        for (final p in _table('/employees'))
          ..._leaveBalancesFor(p['id'], year),
      ], r);
    }
    if (r.path == '/leave/admin/ledger' && r.method == 'GET') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      return _page(_table('/leave/ledger'), r);
    }
    final adjustment = RegExp(r'^/leave/admin/balances/([^/]+)/adjust$')
        .firstMatch(r.path);
    if (adjustment != null && r.method == 'POST') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      final person = adjustment[1]!;
      _person(person);
      _need(
        person != employeeId,
        'INDEPENDENT_APPROVAL',
        'Another authorized HR administrator must adjust your balance.',
        status: 403,
      );
      _reason(body);
      final year = body['year'];
      _need(
        year is int && year >= 2020 && year <= 2100,
        'VALIDATION_ERROR',
        'Choose a valid accounting year.',
      );
      final balances = _leaveBalancesFor(person, year),
          balance = balances
              .where((b) => b['leaveTypeId'] == body['leaveTypeId'])
              .firstOrNull;
      _need(
        balance != null,
        'NOT_FOUND',
        'Leave balance not found.',
        status: 404,
      );
      _version(r, balance!);
      final units = _units(body['delta']);
      _need(
        units != 0 && units.abs() <= 36600,
        'VALIDATION_ERROR',
        'Provide a non-zero adjustment of at most 366 days.',
      );
      _need(
        _units(balance['available']) + units >= 0,
        'NEGATIVE_AVAILABILITY',
        'This adjustment would make available leave negative.',
        status: 409,
      );
      _leaveEntry(
        {'employeeId': person, 'leaveTypeId': body['leaveTypeId'], 'id': _id()},
        'ADJUST',
        units: units,
        year: year,
        reason: body['reason'],
      );
      _auditAction('LEAVE_ADJUSTED', person);
      final updated = _leaveBalancesFor(
        person,
        year,
      ).firstWhere((b) => b['leaveTypeId'] == body['leaveTypeId']);
      return _ok(updated, etag: updated['etag']);
    }
    final policy = RegExp(r'^/leave/admin/policies/([^/]+)$')
        .firstMatch(r.path);
    if (policy != null && r.method == 'PUT') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      _reason(body);
      final type = _find('/leave/types', policy[1]!);
      _version(r, type);
      final entitlement = _units(body['annualDays']),
          carry = _units(body['carryOverMax']);
      _need(
        entitlement >= 0 &&
            entitlement <= 36600 &&
            carry >= 0 &&
            carry <= 36600,
        'VALIDATION_ERROR',
        'Choose valid entitlement and carry-over limits.',
      );
      _need(
        body['maxDaysPerRequest'] is int &&
            body['maxDaysPerRequest'] >= 1 &&
            body['maxDaysPerRequest'] <= 366,
        'VALIDATION_ERROR',
        'Choose a valid request limit.',
      );
      _need(
        body['minNoticeDays'] == null ||
            (body['minNoticeDays'] is int &&
                body['minNoticeDays'] >= 0 &&
                body['minNoticeDays'] <= 365),
        'VALIDATION_ERROR',
        'Choose a valid minimum notice.',
      );
      type.addAll({
        'annualDays': entitlement / 100,
        'entitled': entitlement / 100,
        'carryOverMax': carry / 100,
        'allowHalfDay': body['allowHalfDay'] == true,
        'requiresAttachment': body['requiresAttachment'] == true,
        'maxDaysPerRequest': body['maxDaysPerRequest'],
        'minNoticeDays': body['minNoticeDays'] ?? 0,
      });
      type['version']++;
      _auditAction('LEAVE_POLICY_UPDATED', type['id']);
      return _ok(type, etag: '"${type['version']}"');
    }
    if (r.path == '/leave/admin/year-end/preview' && r.method == 'POST') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      _reason(body);
      final year = body['fromYear'];
      _need(
        year is int && year >= 2020 && year < 2100,
        'VALIDATION_ERROR',
        'Choose a closing year.',
      );
      final cap = _units(body['carryLimit']);
      _need(
        cap >= 0 && cap <= 36600,
        'VALIDATION_ERROR',
        'Choose a valid approved carry-over maximum.',
      );
      _need(
        !_table('/leave/requests').any(
          (row) =>
              row['status'] == 'PENDING' &&
              DateTime.parse(row['startDate']).year <= year &&
              DateTime.parse(row['endDate']).year > year,
        ),
        'PENDING_CROSS_YEAR',
        'Resolve pending cross-year requests before closing this year.',
        status: 409,
      );
      final allocations = <JsonMap>[];
      for (final p in _table(
        '/employees',
      ).where((p) => p['status'] == 'ACTIVE')) {
        for (final balance in _leaveBalancesFor(p['id'], year)) {
          final policyCap = _units(
            _find('/leave/types', balance['leaveTypeId'])['carryOverMax'] ??
                body['carryLimit'],
          );
          final available = _units(balance['available']);
          final units = available.clamp(0, cap < policyCap ? cap : policyCap);
          final nextBalance = _leaveBalancesFor(
            p['id'],
            year + 1,
          ).firstWhere((b) => b['leaveTypeId'] == balance['leaveTypeId']);
          allocations.add({
            'employeeId': p['id'],
            'employeeName': p['name'],
            'leaveTypeId': balance['leaveTypeId'],
            'leaveTypeName': balance['name'],
            'currentBalance': available / 100,
            'carriedOver': units / 100,
            'forfeited': (available - units).clamp(0, 100000000) / 100,
            'newBalance': (nextBalance['available'] as num) + units / 100,
            'units': units,
          });
        }
      }
      final row = <String, dynamic>{
        'id': _id(),
        'fromYear': year,
        'toYear': year + 1,
        'carryLimit': cap / 100,
        'allocations': allocations,
        'basis': _rolloverBasis(year),
        'reason': body['reason'],
        'version': 1,
      };
      _table('/leave/rollover-previews').add(row);
      return _ok({
        'previewId': row['id'],
        'rows': allocations,
        'affectedEmployees': allocations
            .where((a) => (a['units'] as int) > 0)
            .map((a) => a['employeeId'])
            .toSet()
            .length,
        'totalCarried':
            allocations.fold<int>(0, (v, a) => v + (a['units'] as int)) / 100,
        'totalForfeited': allocations.fold<num>(
          0,
          (v, a) => v + (a['forfeited'] as num),
        ),
        'summary':
            '${allocations.length} employee/type balances reviewed. ${formatLeaveDays(allocations.fold<int>(0, (v, r) => v + (r['units'] as int)) / 100)} will carry to ${year + 1}. Pending cross-year requests must be resolved.',
      }, status: 201);
    }
    if (r.path == '/leave/admin/year-end' && r.method == 'GET') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      return _page(_table('/leave/rollovers'), r);
    }
    if (r.path == '/leave/admin/year-end' && r.method == 'POST') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      _reason(body);
      final preview = _find(
        '/leave/rollover-previews',
        body['previewId'] as String? ?? '',
      );
      _need(
        preview['fromYear'] == body['fromYear'] &&
            preview['carryLimit'] == body['carryLimit'],
        'PREVIEW_CHANGED',
        'Preview this exact carry-over policy before applying it.',
        status: 409,
      );
      _need(
        !_table('/leave/rollovers')
            .any((job) => job['fromYear'] == preview['fromYear']),
        'ROLLOVER_EXISTS',
        'This closing year has already been processed.',
        status: 409,
      );
      _need(
        preview['basis'] == _rolloverBasis(preview['fromYear']),
        'STALE_PREVIEW',
        'Balances changed. Prepare a new preview.',
        status: 409,
      );
      for (final allocation in preview['allocations'] as List) {
        _leaveEntry(
          {
            'employeeId': allocation['employeeId'],
            'leaveTypeId': allocation['leaveTypeId'],
            'id': preview['id'],
          },
          'ROLLOVER',
          units: allocation['units'],
          year: preview['toYear'],
          reason: body['reason'],
        );
      }
      final job = <String, dynamic>{
        'id': _id(),
        'name': 'Year-end ${preview['fromYear']}',
        'status': 'COMPLETED',
        'fromYear': preview['fromYear'],
        'toYear': preview['toYear'],
        'carryLimit': preview['carryLimit'],
        'appliedEmployees': _table('/employees')
            .where((p) => p['status'] == 'ACTIVE')
            .length,
        'createdAt': _now().toUtc().toIso8601String(),
        'version': 1,
      };
      _table('/leave/rollovers').insert(0, job);
      _auditAction('YEAR_END_APPLIED', job['id']);
      return _ok(job, status: 202);
    }
    if (r.path.startsWith('/leave/admin/year-end/') && r.method == 'GET') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      return _ok(_find('/leave/rollovers', r.path.split('/').last));
    }
    if (r.path == '/leave/conflicts' && r.method == 'GET') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      return _page(
        _table('/leave/conflicts').map((c) {
          final leave = _find('/leave/requests', c['leaveRequestId']);
          return <String, dynamic>{
            ...c,
            'version': leave['version'],
            'etag': '"${leave['version']}"',
          };
        }),
        r,
      );
    }
    final conflict = RegExp(r'^/leave/requests/([^/]+)/resolve-conflict$')
        .firstMatch(r.path);
    if (conflict != null && r.method == 'POST') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      _reason(body);
      final row = _find('/leave/requests', conflict[1]!);
      _version(r, row);
      _need(
        row['employeeId'] != employeeId,
        'SELF_APPROVAL',
        'An independent HR reviewer must decide.',
        status: 403,
      );
      final review = _table('/leave/conflicts')
          .where(
            (c) =>
                c['conflictId'] == body['conflictId'] &&
                c['leaveRequestId'] == row['id'] &&
                c['status'] == 'NEEDS_REVIEW',
          )
          .firstOrNull;
      _need(
        review != null && row['status'] == 'APPROVED',
        'INVALID_TRANSITION',
        'This conflict is no longer awaiting review.',
        status: 409,
      );
      _need(
        ['KEEP_LEAVE', 'CANCEL_LEAVE'].contains(body['action']),
        'VALIDATION_ERROR',
        'Choose keep or cancel leave.',
      );
      if (body['action'] == 'CANCEL_LEAVE') {
        row['status'] = 'CANCELLED';
        _leaveEntry(row, 'COMPENSATE', reason: body['reason']);
      }
      if (body['action'] == 'CANCEL_LEAVE') {
        for (final other in _table('/leave/conflicts').where(
          (c) =>
              c['leaveRequestId'] == row['id'] && c['status'] == 'NEEDS_REVIEW',
        )) {
          other['status'] = 'RESOLVED';
          other['resolution'] = body['action'];
          other['reason'] = body['reason'];
        }
      }
      row['syncState'] =
          _table('/leave/conflicts').any(
            (c) =>
                c['leaveRequestId'] == row['id'] &&
                c['id'] != review!['id'] &&
                c['status'] == 'NEEDS_REVIEW',
          )
          ? 'NEEDS_REVIEW'
          : 'SYNCED';
      row['version']++;
      review!['status'] = 'RESOLVED';
      review['resolution'] = body['action'];
      review['reason'] = body['reason'];
      _auditAction('LEAVE_CONFLICT_RESOLVED', row['id']);
      return _ok(row, etag: '"${row['version']}"');
    }
    return null;
  }

  void _detectLeaveConflict(JsonMap session) {
    final date = DateTime.parse(session['checkInAt'])
        .toUtc()
        .add(const Duration(hours: 7))
        .toIso8601String()
        .substring(0, 10);
    for (final leave in _table('/leave/requests').where(
      (l) =>
          l['employeeId'] == session['employeeId'] &&
          l['status'] == 'APPROVED' &&
          (l['startDate'] as String).compareTo(date) <= 0 &&
          (l['endDate'] as String).compareTo(date) >= 0,
    )) {
      if (_table('/leave/conflicts').any(
        (c) =>
            c['leaveRequestId'] == leave['id'] &&
            c['workDate'] == date &&
            c['status'] == 'NEEDS_REVIEW',
      )) {
        continue;
      }
      final id = _id();
      _table('/leave/conflicts').add({
        'id': id,
        'conflictId': id,
        'leaveRequestId': leave['id'],
        'employeeId': leave['employeeId'],
        'employeeName': _employeeName(leave['employeeId']),
        'name': '${_employeeName(leave['employeeId'])} · leave review',
        'typeName': leave['title'],
        'workDate': date,
        'reason': 'Recorded work overlaps approved leave.',
        'attendanceSummary': '${session['source']} work evidence is retained.',
        'status': 'NEEDS_REVIEW',
        'version': leave['version'],
      });
      leave['syncState'] = 'NEEDS_REVIEW';
    }
  }
}
