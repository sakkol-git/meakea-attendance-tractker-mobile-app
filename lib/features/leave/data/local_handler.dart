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
        type!['allowHalfDay'] != false,
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
      days <= (type!['maxDaysPerRequest'] as num? ?? 60),
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
    if (r.path == '/leave/balances/me' && r.method == 'GET') {
      return _page(_balances(), r);
    }
    return _catalogue(r, ['/leave/types']);
  }
}
