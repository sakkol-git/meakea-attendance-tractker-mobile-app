part of '../../../core/demo/local_service.dart';

extension IdentityCasesDemo on LocalDataSource {
  JsonMap get _company =>
      _table('/company').firstOrNull ??
      {
        'id': 'demo-company',
        'name': 'Northstar Studio',
        'slug': 'northstar',
        'timezone': 'Asia/Phnom_Penh',
        'locale': 'en',
        'version': 1,
        'status': 'ACTIVE',
      };
  DataResponse? _identityCases(DataRequest r) {
    final body = r.body ?? {};
    if (r.path == '/shift-assignments' && r.method == 'GET') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      return _page(
        _assignments.map(
          (v) => {
            ...v,
            'employeeName': _employeeName(v['employeeId']),
            'name': '${_employeeName(v['employeeId'])} · shift',
            'shiftName':
                (v['shiftSnapshot'] as Map?)?['name'] ??
                _table('/shifts')
                    .where((s) => s['id'] == v['shiftId'])
                    .firstOrNull?['name'],
            'status': v['validTo'] == null ? 'ACTIVE' : 'CLOSED',
          },
        ),
        r,
      );
    }
    final close = RegExp(r'^/shift-assignments/([^/]+)/close$')
        .firstMatch(r.path);
    if (close != null && r.method == 'POST') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      _reason(body);
      final row = _find('/shift-assignments', close[1]!);
      _version(r, row);
      final end = body['validTo'];
      _need(
        _validDate(end) &&
            (end as String).compareTo(row['validFrom']) >= 0 &&
            end.compareTo(today) >= 0 &&
            (row['validTo'] == null || end.compareTo(row['validTo']) <= 0),
        'VALIDATION_ERROR',
        'Choose today or a future day within the current effective period. Historical assignments cannot be rewritten.',
      );
      row['validTo'] = end;
      row['version']++;
      _auditAction('SHIFT_ASSIGNMENT_CLOSED', row['id']);
      return _ok(row, etag: '"${row['version']}"');
    }
    final shiftResult = _shiftCase(r);
    if (shiftResult != null) return shiftResult;

    if (r.path == '/tenants' && r.method == 'POST') {
      _need(
        (body['name'] as String? ?? '').trim().length >= 3 &&
            RegExp(r'^[a-z0-9-]{3,50}$')
                .hasMatch(body['slug'] as String? ?? ''),
        'VALIDATION_ERROR',
        'Enter a company name and a valid workspace name.',
      );
      _need(
        _table('/company').isEmpty,
        'WORKSPACE_EXISTS',
        'This demo already has a configured workspace. Reset the demo to provision another.',
        status: 409,
      );
      final row = <String, dynamic>{
        'id': 'demo-company',
        'name': body['name'],
        'slug': body['slug'],
        'timezone': 'Asia/Phnom_Penh',
        'locale': 'en',
        'version': 1,
        'status': 'ACTIVE',
      };
      _table('/company').add(row);
      _auditAction('WORKSPACE_PROVISIONED', row['id']);
      return _ok(row, status: 201, etag: '"1"');
    }
    if (r.path == '/tenants/current') {
      _need(
        _admin,
        'FORBIDDEN',
        'Company administration access is required.',
        status: 403,
      );
      if (r.method == 'GET') {
        return _ok(_company, etag: '"${_company['version']}"');
      }
      if (r.method == 'PATCH') {
        _need(
          _actor == 'OWNER',
          'FORBIDDEN',
          'The company owner manages workspace settings.',
          status: 403,
        );
        _version(r, _company);
        _need(
          body['timezone'] == null || body['timezone'] == 'Asia/Phnom_Penh',
          'TIMEZONE_POLICY',
          'This client currently supports the Phnom Penh company calendar only.',
        );
        final row = <String, dynamic>{
          ..._company,
          'name': body['name'] ?? _company['name'],
          'timezone': body['timezone'] ?? _company['timezone'],
          'locale': body['locale'] ?? _company['locale'],
          'version': (_company['version'] as int) + 1,
        };
        _table('/company')
          ..clear()
          ..add(row);
        _auditAction('COMPANY_UPDATED', row['id']);
        return _ok(row, etag: '"${row['version']}"');
      }
    }
    if (r.path == '/employees' && r.method == 'GET' && populate) {
      _need(
        _manages,
        'FORBIDDEN',
        'Management access is required.',
        status: 403,
      );
      return _page(
        _table('/employees').where(
          (row) =>
              _admin ||
              row['id'] == employeeId ||
              row['managerId'] == employeeId,
        ),
        r,
      );
    }
    if (r.path == '/employees' && r.method == 'POST' && populate) {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      _need(
        (body['name'] as String? ?? '').trim().length >= 2 &&
            (body['email'] as String? ?? '').contains('@'),
        'VALIDATION_ERROR',
        'Enter the employee name and work email.',
      );
      _need(
        !_table('/employees').any(
          (row) =>
              (row['email'] as String?)?.toLowerCase() ==
              (body['email'] as String).toLowerCase(),
        ),
        'EMAIL_EXISTS',
        'An employee with this email already exists.',
        status: 409,
      );
      _validatePerson(body, null);
      final row = <String, dynamic>{
        ...body,
        'id': _id(),
        'roles': ['EMPLOYEE'],
        'status': 'ACTIVE',
        'invitationStatus': 'NOT_SENT',
        'version': 1,
        'department':
            _table('/departments')
                .where((v) => v['id'] == body['departmentId'])
                .firstOrNull?['name'] ??
            body['department'] ??
            '',
        'position':
            _table('/positions')
                .where((v) => v['id'] == body['positionId'])
                .firstOrNull?['name'] ??
            body['position'] ??
            '',
      };
      _table('/employees').add(row);
      _auditAction('EMPLOYEE_CREATED', row['id']);
      return _ok(row, status: 201, etag: '"1"');
    }
    final person = RegExp(
      r'^/employees/([^/]+)(?:/(invite|roles|terminate|impact|device|direct-reports))?$',
    ).firstMatch(r.path);
    if (person != null && populate) {
      final id = person[1]!, action = person[2];
      _need(
        _admin ||
            (r.method == 'GET' &&
                (id == employeeId ||
                    (_actor == 'MANAGER' &&
                        _person(id)['managerId'] == employeeId))),
        'FORBIDDEN',
        'This employee operation requires authorized HR access.',
        status: 403,
      );
      final row = _person(id);
      if (r.method == 'GET' && action == null) {
        return _ok(row, etag: '"${row['version']}"');
      }
      if (r.method == 'GET' && action == 'direct-reports') {
        return _page(
          _table('/employees').where((v) => v['managerId'] == id),
          r,
        );
      }
      if (r.method == 'POST' && action == 'impact') {
        _version(r, row);
        final pending = [
          ..._table('/requests'),
          ..._table('/leave/requests'),
          ..._table('/attendance/corrections'),
        ];
        final ownPending = pending
            .where((v) => v['employeeId'] == id && v['status'] == 'PENDING')
            .length;
        final openApprovals = pending
            .where(
              (v) => v['currentApproverId'] == id && v['status'] == 'PENDING',
            )
            .length;
        final issued = _table('/requests')
            .where((v) => v['employeeId'] == id)
            .fold<int>(
              0,
              (total, request) =>
                  total +
                  (request['issuedQuantities'] as Map? ?? {}).values.fold<int>(
                    0,
                    (sum, quantity) => sum + (quantity as num).toInt(),
                  ),
            );
        return _ok({
          'employeeName': row['name'],
          'currentRole': (row['roles'] as List?)?.firstOrNull ?? 'EMPLOYEE',
          'newRole': body['role'],
          'accessEnds': body['effectiveDate'] != null,
          'pendingRequests': ownPending,
          'assignedMaterials': issued,
          'openApprovals': openApprovals,
          'summary': body['effectiveDate'] != null
              ? 'Access ends on ${body['effectiveDate']}. Review outstanding work before terminating employment.'
              : 'Access role changes from ${(row['roles'] as List?)?.firstOrNull ?? 'EMPLOYEE'} to ${body['role']}.',
        });
      }
      if (r.method == 'PATCH' && action == null) {
        _version(r, row);
        final before = copyJson(row) as JsonMap;
        _need(
          body.keys.every(
            {
              'name',
              'email',
              'employeeNo',
              'departmentId',
              'positionId',
              'managerId',
              'hireDate',
            }.contains,
          ),
          'VALIDATION_ERROR',
          'The employee edit contains an unsupported field.',
        );
        _validatePerson(body, id);
        for (final field in [
          'name',
          'email',
          'employeeNo',
          'departmentId',
          'positionId',
          'managerId',
          'hireDate',
        ]) {
          if (body.containsKey(field)) row[field] = body[field];
        }
        if (body['departmentId'] != null) {
          row['department'] = _find(
            '/departments',
            body['departmentId'],
          )['name'];
        }
        if (body['positionId'] != null) {
          row['position'] = _find('/positions', body['positionId'])['name'];
        }
        row['version']++;
        _auditAction(
          'EMPLOYEE_UPDATED',
          id,
          reason: body['reason'] as String?,
          before: before,
          after: row,
        );
        return _ok(row, etag: '"${row['version']}"');
      }
      if (['invite', 'roles', 'terminate', 'device'].contains(action) &&
          ['POST', 'PUT'].contains(r.method)) {
        _version(r, row);
        final before = copyJson(row) as JsonMap;
        if (action == 'roles') {
          _need(
            _actor == 'OWNER' && id != employeeId,
            'FORBIDDEN',
            'An independent owner must authorize access-role changes.',
            status: 403,
          );
          _reason(body);
          final role = body['role'] ?? (body['roles'] as List?)?.firstOrNull;
          _need(
            LocalDataSource.roles.contains(role),
            'VALIDATION_ERROR',
            'Choose a supported access role.',
          );
          row['roles'] = [role];
        } else if (action == 'terminate') {
          _need(
            id != employeeId,
            'SELF_ACTION',
            'Ask another authorized administrator to record your employment change.',
            status: 403,
          );
          _reason(body);
          _need(
            _validDate(body['effectiveDate']),
            'VALIDATION_ERROR',
            'Select the last employment day.',
          );
          row['status'] =
              (body['effectiveDate'] as String).compareTo(today) <= 0
              ? 'TERMINATED'
              : 'ENDING';
          row['terminationDate'] = body['effectiveDate'];
        } else if (action == 'invite') {
          _need(
            row['status'] == 'ACTIVE',
            'INVALID_TRANSITION',
            'Only active employees can be invited.',
            status: 409,
          );
          _reason(body);
          row['invitationStatus'] = 'QUEUED';
        } else {
          row['deviceId'] = body['deviceId'];
        }
        row['version']++;
        _auditAction(
          'EMPLOYEE_${action!.toUpperCase()}',
          id,
          reason: body['reason'] as String?,
          before: before,
          after: row,
        );
        return _ok(row, etag: '"${row['version']}"');
      }
    }
    if (r.path == '/work-sites' && r.method == 'GET') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      return _page(_table('/work-sites'), r);
    }
    if (r.path == '/work-sites' && r.method == 'POST' ||
        r.path.startsWith('/work-sites/') &&
            ['PATCH', 'DELETE'].contains(r.method)) {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      final row = r.method == 'POST'
          ? <String, dynamic>{'id': _id(), 'version': 0}
          : _find('/work-sites', r.path.split('/').last);
      if (r.method != 'POST') _version(r, row);
      if (r.method == 'DELETE') {
        _reason(body);
        row['status'] = 'ARCHIVED';
      } else {
        final lat = body['latitude'],
            lng = body['longitude'],
            radius = body['radiusM'];
        _need(
          lat is num &&
              lat.isFinite &&
              lat >= -90 &&
              lat <= 90 &&
              lng is num &&
              lng.isFinite &&
              lng >= -180 &&
              lng <= 180 &&
              radius is num &&
              radius >= 10 &&
              radius <= 10000,
          'VALIDATION_ERROR',
          'Provide a valid site location and radius.',
        );
        row.addAll(body);
        row['status'] = 'ACTIVE';
        row['timezone'] =
            body['timezone'] ?? row['timezone'] ?? 'Asia/Phnom_Penh';
      }
      row['version']++;
      if (r.method == 'POST') _table('/work-sites').add(row);
      _auditAction('SITE_UPDATED', row['id']);
      return _ok(
        row,
        status: r.method == 'POST' ? 201 : 200,
        etag: '"${row['version']}"',
      );
    }
    if (RegExp(r'^/(departments|positions|holidays)/[^/]+$').hasMatch(r.path) &&
        r.method == 'DELETE') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      _reason(body);
      final group = '/${r.path.split('/')[1]}',
          id = r.path.split('/').last,
          row = _find(group, id);
      _version(r, row);
      _need(
        !_table('/employees').any(
          (p) =>
              p['status'] == 'ACTIVE' &&
              (p['departmentId'] == id || p['positionId'] == id),
        ),
        'ACTIVE_REFERENCES',
        'Reassign active employees before archiving this record.',
        status: 409,
      );
      row['status'] = 'ARCHIVED';
      row['version']++;
      _auditAction('CATALOG_ARCHIVED', id);
      return _ok(row, etag: '"${row['version']}"');
    }
    return null;
  }

  void _validatePerson(JsonMap body, String? id) {
    for (final pair in [
      ('departmentId', '/departments'),
      ('positionId', '/positions'),
    ]) {
      if (body[pair.$1] != null) _find(pair.$2, body[pair.$1]);
    }
    String? manager = body['managerId'] as String?;
    final seen = <String>{?id};
    while (manager != null && manager.isNotEmpty) {
      _need(
        seen.add(manager),
        'MANAGER_CYCLE',
        'Choose a manager outside this employee’s reporting chain.',
        status: 409,
      );
      manager = _person(manager)['managerId'] as String?;
    }
  }
}
