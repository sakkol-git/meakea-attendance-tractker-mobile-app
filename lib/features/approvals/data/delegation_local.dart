part of '../../../core/demo/local_service.dart';

extension DelegationDemo on LocalDataSource {
  bool _delegatedReviewer(JsonMap record) {
    final owner =
        record['currentApproverId'] ??
        _table('/employees')
            .where((person) => person['id'] == record['employeeId'])
            .firstOrNull?['managerId'];
    return (_rows['/approval-delegations'] ?? []).any(
      (delegation) =>
          delegation['ownerId'] == owner &&
          delegation['delegateId'] == employeeId &&
          delegation['status'] == 'ACTIVE' &&
          '${delegation['startsOn']}'.compareTo(today) <= 0 &&
          '${delegation['endsOn']}'.compareTo(today) >= 0,
    );
  }

  DataResponse? _handleDelegations(DataRequest request) {
    const path = '/approvals/delegations';
    if (request.path == '/approvals/eligible-delegates' &&
        request.method == 'GET') {
      _need(_manages, 'FORBIDDEN', 'Manager access is required.', status: 403);
      return _page(
        _table('/employees').where(
          (person) =>
              person['id'] != employeeId &&
              person['status'] == 'ACTIVE' &&
              ([
                    'demo-manager',
                    'demo-hr',
                    'demo-owner',
                  ].contains(person['id']) ||
                  (person['roles'] as List? ?? []).any(
                    (role) => ['MANAGER', 'HR_ADMIN', 'OWNER'].contains(role),
                  )),
        ),
        request,
      );
    }
    if (request.path != path && !request.path.startsWith('$path/')) return null;
    _need(_manages, 'FORBIDDEN', 'Manager access is required.', status: 403);
    final rows = _rows.putIfAbsent('/approval-delegations', () => []);
    if (request.method == 'GET' && request.path == path) {
      return _page(
        rows.where(
          (row) =>
              row['ownerId'] == employeeId || row['delegateId'] == employeeId,
        ),
        request,
      );
    }
    if (request.method == 'POST' && request.path == path) {
      final body = request.body ?? {};
      final delegateId = body['delegateId'] as String? ?? '';
      final delegate = _table('/employees')
          .where(
            (person) =>
                person['id'] == delegateId && person['status'] == 'ACTIVE',
          )
          .firstOrNull;
      _need(
        delegate != null &&
            delegateId != employeeId &&
            ['demo-manager', 'demo-hr', 'demo-owner'].contains(delegateId),
        'VALIDATION_ERROR',
        'Choose another active reviewer.',
      );
      final start = body['startsOn'] as String? ?? '';
      final end = body['endsOn'] as String? ?? '';
      _need(
        _validDate(start) && _validDate(end) && start.compareTo(end) <= 0,
        'VALIDATION_ERROR',
        'Choose a valid delegation period.',
      );
      final reason = (body['reason'] as String? ?? '').trim();
      _need(reason.length >= 5, 'VALIDATION_ERROR', 'Explain the delegation.');
      _need(
        !rows.any(
          (row) =>
              row['ownerId'] == employeeId &&
              row['status'] == 'ACTIVE' &&
              '${row['startsOn']}'.compareTo(end) <= 0 &&
              '${row['endsOn']}'.compareTo(start) >= 0,
        ),
        'OVERLAP',
        'An active delegation overlaps this period.',
        status: 409,
      );
      final row = <String, dynamic>{
        'id': _id(),
        'ownerId': employeeId,
        'delegateId': delegateId,
        'delegateName': delegate!['name'],
        'startsOn': start,
        'endsOn': end,
        'reason': reason,
        'status': 'ACTIVE',
        'version': 1,
      };
      rows.add(row);
      _auditAction('DELEGATED_APPROVALS', row['id']);
      return _ok(row, status: 201, etag: '"1"');
    }
    if (request.method == 'DELETE' && request.path.startsWith('$path/')) {
      final id = request.path.substring(path.length + 1);
      final row = rows
          .where((item) => item['id'] == id && item['ownerId'] == employeeId)
          .firstOrNull;
      _need(row != null, 'NOT_FOUND', 'Delegation not found.', status: 404);
      _version(request, row!);
      row['status'] = 'CANCELLED';
      row['version'] = (row['version'] as int) + 1;
      _auditAction('CANCELLED_DELEGATION', id);
      return _ok(row, etag: '"${row['version']}"');
    }
    return null;
  }
}
