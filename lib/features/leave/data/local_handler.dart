part of '../../../core/demo/local_service.dart';

extension LeaveDemo on LocalDataSource {
  List<JsonMap> _balances() => _leaveBalancesFor(employeeId, _companyNow.year);
  void _validateLeave(String path, JsonMap body) {
    final type = _rows['/leave/types']!
        .where((v) => v['id'] == body['leaveTypeId'])
        .firstOrNull;
    _need(type != null, 'VALIDATION_ERROR', 'Select a leave type.');
    final start = DateTime.tryParse(body['startDate'] as String? ?? ''),
        end = DateTime.tryParse(body['endDate'] as String? ?? '');
    _need(
      _validDate(body['startDate']) &&
          _validDate(body['endDate']) &&
          start != null &&
          end != null &&
          !end.isBefore(start),
      'VALIDATION_ERROR',
      'Choose a valid date range.',
    );
    _need(
      end!.difference(start!).inDays <= 60,
      'VALIDATION_ERROR',
      'Choose a period of at most 60 days.',
    );
    final notice = (type!['minNoticeDays'] as num? ?? 0).toInt();
    _need(
      start.difference(_companyNow).inDays >= notice,
      'POLICY',
      'This leave type requires $notice days of notice.',
    );
    double days = 0;
    final portions = <JsonMap>[];
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      final date = d.toIso8601String().substring(0, 10);
      final shift = _assignedShift(employeeId, date);
      final mask = shift?['workingDays'] as int? ?? 31;
      if ((mask & (1 << (d.weekday - 1))) != 0 &&
          !_rows['/holidays']!.any(
            (h) =>
                h['status'] != 'ARCHIVED' &&
                h['date'] == d.toIso8601String().substring(0, 10),
          )) {
        days++;
        portions.add({
          'date': d.toIso8601String().substring(0, 10),
          'units': 100,
          'portion': 'FULL',
        });
      }
    }
    if (body['halfDay'] != 'NONE' && body['halfDay'] != null) {
      _need(
        start == end,
        'VALIDATION_ERROR',
        'Half-day leave must be on one date.',
      );
      _need(
        type['allowHalfDay'] != false,
        'POLICY',
        'This leave type does not allow half days.',
      );
      days = days / 2;
      if (portions.isNotEmpty) {
        portions.first['units'] = 50;
        portions.first['portion'] = body['halfDay'];
      }
    }
    _need(
      days > 0,
      'VALIDATION_ERROR',
      'The selected period has no scheduled workdays.',
    );
    for (final year
        in portions
            .map((p) => int.parse((p['date'] as String).substring(0, 4)))
            .toSet()) {
      final quantity = portions
          .where((p) => (p['date'] as String).startsWith('$year-'))
          .fold<int>(0, (v, p) => v + (p['units'] as int));
      final balance = _leaveBalancesFor(
        employeeId,
        year,
      ).firstWhere((b) => b['leaveTypeId'] == body['leaveTypeId']);
      _need(
        _units(balance['available']) >= quantity,
        'LEAVE_BALANCE_INSUFFICIENT',
        'Not enough available leave for $year.',
      );
    }
    _need(
      !_own(_rows[path]!).any(
        (r) =>
            ['PENDING', 'APPROVED'].contains(r['status']) &&
            !(DateTime.parse(r['endDate']).isBefore(start) ||
                DateTime.parse(r['startDate']).isAfter(end)),
      ),
      'LEAVE_OVERLAP',
      'This period overlaps an existing leave request.',
    );
    _need(
      days <= (type['maxDaysPerRequest'] as num? ?? 60),
      'POLICY',
      'This period exceeds the leave policy limit.',
    );
    body['dayPortions'] = portions;
    body['days'] = days;
    body['title'] = body['typeName'] = type['name'];
  }

  DataResponse? _handleLeave(DataRequest r) {
    final caseResult = _leaveCases(r);
    if (caseResult != null) return caseResult;
    if (r.path == '/leave/requests/preview' && r.method == 'POST') {
      final body = r.body ?? {};
      final type = _table('/leave/types')
          .where(
            (value) =>
                value['id'] == body['leaveTypeId'] &&
                value['status'] != 'ARCHIVED',
          )
          .firstOrNull;
      _need(type != null, 'VALIDATION_ERROR', 'Choose a leave type.');
      final from = DateTime.tryParse(body['startDate'] as String? ?? '');
      final to = DateTime.tryParse(body['endDate'] as String? ?? '');
      _need(
        from != null &&
            to != null &&
            !to.isBefore(from) &&
            to.difference(from).inDays <= 60,
        'VALIDATION_ERROR',
        'Choose a valid period of at most 60 days.',
      );
      var units = 0;
      for (
        var day = from!;
        !day.isAfter(to!);
        day = day.add(const Duration(days: 1))
      ) {
        final date = day.toIso8601String().substring(0, 10);
        final mask =
            _assignedShift(employeeId, date)?['workingDays'] as int? ?? 31;
        if ((mask & (1 << (day.weekday - 1))) != 0 &&
            !_table('/holidays')
                .any((h) => h['date'] == date && h['status'] != 'ARCHIVED')) {
          units += 100;
        }
      }
      final allowHalfDay = type!['allowHalfDay'] != false;
      final half = body['halfDay'] != null && body['halfDay'] != 'NONE';
      if (half && from == to && allowHalfDay) units ~/= 2;
      final balance = _leaveBalancesFor(
        employeeId,
        from.year,
      ).firstWhere((row) => row['leaveTypeId'] == type['id']);
      final available = _units(balance['available']);
      final notice = (type['minNoticeDays'] as num? ?? 0).toInt();
      final warnings = <String>[
        if (units == 0) 'No scheduled workdays in this period.',
        if (half && !allowHalfDay) 'This leave type does not allow half days.',
        if (half && from != to) 'Half-day leave must be on one date.',
        if (units > available) 'Insufficient available balance.',
        if (units / 100 > (type['maxDaysPerRequest'] as num? ?? 60))
          'This period exceeds the policy limit.',
        if (from.difference(_companyNow).inDays < notice)
          'This leave type requires $notice days of notice.',
        if (from.year != to.year)
          'This request crosses an accounting year; review both balances.',
      ];
      return _ok({
        'chargeableDays': units / 100,
        'balanceBefore': available / 100,
        'balanceAfter': (available - units) / 100,
        'allowHalfDay': allowHalfDay,
        'evidenceRequired': type['requiresAttachment'] == true,
        'minimumNoticeDays': notice,
        'warnings': warnings,
      });
    }
    if (r.path == '/leave/balances/me' && r.method == 'GET') {
      return _page(_balances(), r);
    }
    return _catalogue(r, ['/leave/types']);
  }
}
