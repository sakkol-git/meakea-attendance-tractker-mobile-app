part of '../../../core/demo/local_service.dart';

extension IdentityDemo on LocalDataSource {
  List<JsonMap> get _assignments =>
      _rows.putIfAbsent('/shift-assignments', () => []);
  bool _knownEmployee(String id) =>
      _rows['/employees']!.any((row) => row['id'] == id);
  JsonMap? _assignedShift(String id, String date) {
    final assignment = _assignments
        .where(
          (row) =>
              row['employeeId'] == id &&
              (row['validFrom'] as String).compareTo(date) <= 0 &&
              (row['validTo'] == null ||
                  (row['validTo'] as String).compareTo(date) >= 0),
        )
        .firstOrNull;
    return assignment == null
        ? null
        : assignment['shiftSnapshot'] is Map
        ? JsonMap.from(assignment['shiftSnapshot'])
        : _rows['/shifts']!
              .where((row) => row['id'] == assignment['shiftId'])
              .firstOrNull;
  }

  DataResponse? _handleIdentity(DataRequest r) {
    final caseResult = _identityCases(r);
    if (caseResult != null) return caseResult;
    final body = r.body ?? {};
    if (r.path == '/auth/me' && r.method == 'GET') return _ok(profile);
    final shiftAssignments = RegExp(r'^/employees/([^/]+)/shifts$')
        .firstMatch(r.path);
    if (shiftAssignments != null) {
      final target = shiftAssignments[1]!;
      _need(
        _admin || (r.method == 'GET' && target == employeeId),
        'FORBIDDEN',
        'Only HR can manage assignments; employees can read their own schedule.',
        status: 403,
      );
      _need(
        _knownEmployee(target) || (r.method == 'GET' && target == employeeId),
        'NOT_FOUND',
        'Employee not found.',
        status: 404,
      );
      if (r.method == 'GET') {
        final rows =
            _assignments
                .where((row) => row['employeeId'] == target)
                .map(
                  (row) => <String, dynamic>{
                    ...row,
                    'shiftName':
                        _rows['/shifts']!
                            .where((shift) => shift['id'] == row['shiftId'])
                            .firstOrNull?['name'] ??
                        'Work shift',
                  },
                )
                .toList()
              ..sort(
                (a, b) => (b['validFrom'] as String).compareTo(
                  a['validFrom'] as String,
                ),
              );
        return _page(rows, r);
      }
      if (r.method == 'POST') {
        final shift = _rows['/shifts']!
            .where((row) => row['id'] == body['shiftId'])
            .firstOrNull;
        _need(
          shift != null,
          'VALIDATION_ERROR',
          'Select an existing work shift.',
        );
        final from = body['validFrom'], to = body['validTo'];
        _need(
          _validDate(from) &&
              (to == null ||
                  (_validDate(to) &&
                      (to as String).compareTo(from as String) >= 0)),
          'VALIDATION_ERROR',
          'Choose a valid effective date range.',
        );
        _need(
          !_assignments.any(
            (row) =>
                row['employeeId'] == target &&
                !(row['validTo'] != null &&
                    (row['validTo'] as String).compareTo(from as String) < 0) &&
                !(to != null &&
                    (to as String).compareTo(row['validFrom'] as String) < 0),
          ),
          'SHIFT_ASSIGNMENT_OVERLAP',
          'These dates overlap an existing assignment. Choose a separate effective period.',
          status: 409,
        );
        final assignment = <String, dynamic>{
          'id': _id(),
          'employeeId': target,
          'shiftId': shift!['id'],
          'shiftSnapshot': copyJson(shift),
          'validFrom': from,
          'validTo': to,
          'version': 1,
        };
        _assignments.add(assignment);
        _auditAction('SHIFT_ASSIGNED', target);
        return _ok(
          {...assignment, 'shiftName': shift['name']},
          status: 201,
          etag: '"1"',
        );
      }
    }
    if (r.path == '/auth/change-password' && r.method == 'POST') {
      return _ok({'message': 'Password changed.'});
    }
    if (r.path == '/profile' && r.method == 'PATCH') {
      final overrides = _rows.putIfAbsent('/profile-overrides', () => []);
      overrides.removeWhere((v) => v['employeeId'] == employeeId);
      overrides.add({
        'employeeId': employeeId,
        'name': body['name'] ?? profile['name'],
        'phone': body['phone'] ?? profile['phone'],
      });
      return _ok(profile);
    }
    if (r.path == '/audit-logs' && r.method == 'GET') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      return _page(
        _audit
            .where(
              (row) =>
                  (r.query['actor']?.isEmpty ?? true) ||
                  row['actor'].toString().toLowerCase().contains(
                    r.query['actor']!.toLowerCase(),
                  ),
            )
            .where(
              (row) =>
                  (r.query['action']?.isEmpty ?? true) ||
                  row['action'].toString().toLowerCase().contains(
                    r.query['action']!.toLowerCase(),
                  ),
            )
            .where(
              (row) =>
                  (r.query['target']?.isEmpty ?? true) ||
                  row['entityId'].toString().toLowerCase().contains(
                    r.query['target']!.toLowerCase(),
                  ),
            )
            .where(
              (row) =>
                  (r.query['from']?.isEmpty ?? true) ||
                  row['at']
                          .toString()
                          .substring(0, 10)
                          .compareTo(r.query['from']!) >=
                      0,
            )
            .where(
              (row) =>
                  (r.query['to']?.isEmpty ?? true) ||
                  row['at']
                          .toString()
                          .substring(0, 10)
                          .compareTo(r.query['to']!) <=
                      0,
            ),
        r,
      );
    }
    return _catalogue(r, [
      '/employees',
      '/departments',
      '/positions',
      '/shifts',
      '/holidays',
    ]);
  }
}
