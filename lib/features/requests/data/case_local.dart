part of '../../../core/demo/local_service.dart';

extension RequestCasesDemo on LocalDataSource {
  List<JsonMap> get _requestTypes => _rows.putIfAbsent(
    '/requests/types',
    () => [
      for (final type in [
        'GENERAL',
        'MATERIAL',
        'REMOTE_WORK',
        'LATE_ARRIVAL',
        'EARLY_LEAVE',
      ])
        {
          'id': type.toLowerCase().replaceAll('_', '-'),
          'name': type.replaceAll('_', ' '),
          'code': type,
          'active': true,
          'requiresAttachment': false,
          'version': 1,
          'status': 'ACTIVE',
        },
    ],
  );
  void _prepareRequestApproval(JsonMap row) {
    final chain = _table('/requests/approval-chains')
        .where(
          (c) => c['requestType'] == row['type'] && c['status'] != 'ARCHIVED',
        )
        .firstOrNull;
    row['approvalSnapshot'] = copyJson(
      chain ??
          {
            'name': 'Manager review',
            'managerId': _table('/employees')
                .where((p) => p['id'] == row['employeeId'])
                .firstOrNull?['managerId'],
            'requireHr': row['type'] == 'MATERIAL',
          },
    );
    final manager = (row['approvalSnapshot'] as Map)['managerId'];
    if (manager != null) {
      row['currentApproverId'] = manager;
      row['currentApproverName'] = _employeeName(manager);
    }
    _need(
      manager is String &&
          manager != row['employeeId'] &&
          _table('/employees')
              .any((p) => p['id'] == manager && p['status'] == 'ACTIVE'),
      'APPROVER_REQUIRED',
      'Assign an independent active manager or configure an approval chain before submitting.',
      status: 409,
    );
    row['approvalStage'] = 'MANAGER';
  }

  void _checkRequestApprover(JsonMap row) {
    if (row['approvalStage'] == 'HR') {
      _need(_admin, 'FORBIDDEN', 'This step requires HR review.', status: 403);
    } else if (row['currentApproverId'] != null) {
      _need(
        row['currentApproverId'] == employeeId,
        'NOT_ASSIGNED',
        'This approval step belongs to another reviewer.',
        status: 403,
      );
    }
  }

  bool _advanceRequestApproval(JsonMap row) {
    final snapshot = row['approvalSnapshot'] as Map?;
    final requireHr = snapshot?['requireHr'] ?? row['type'] == 'MATERIAL';
    if (row['approvalStage'] != 'HR' && requireHr == true) {
      row['approvalStage'] = 'HR';
      row.remove('currentApproverId');
      row.remove('currentApproverName');
      return false;
    }
    return true;
  }

  bool _fulfillMaterial(JsonMap row, JsonMap body) {
    _need(
      row['type'] == 'MATERIAL',
      'INVALID_TYPE',
      'Only material requests can be issued.',
      status: 409,
    );
    final items = row['items'] as List? ?? [];
    if (items.isEmpty) {
      row['fulfilledQuantity'] = row['quantity'] ?? 1;
      return true;
    }
    final issued = Map<String, dynamic>.from(
      row['issuedQuantities'] as Map? ?? {},
    );
    final requested = body['materialId'] != null
        ? [
            {'materialId': body['materialId'], 'quantity': body['quantity']},
          ]
        : body['items'] as List? ??
              [
                for (final item in items)
                  {
                    'materialId': item['materialId'],
                    'quantity':
                        (item['quantity'] as num).toInt() -
                        (issued[item['materialId']] as int? ?? 0),
                  },
              ];
    final combined = <String, int>{};
    for (final entry in requested) {
      final qty = entry['quantity'];
      _need(
        qty is num && qty.isFinite && qty % 1 == 0 && qty > 0,
        'VALIDATION_ERROR',
        'Issue a positive whole quantity.',
      );
      final id = entry['materialId'] as String;
      combined[id] = (combined[id] ?? 0) + (qty as num).toInt();
    }
    for (final entry in combined.entries) {
      final item = items
          .where((item) => item['materialId'] == entry.key)
          .firstOrNull;
      _need(
        item != null,
        'INVALID_MATERIAL',
        'This material is not part of the approved request.',
      );
      final remaining =
              (item['quantity'] as num).toInt() -
              (issued[entry.key] as int? ?? 0),
          stock = _find('/materials', entry.key);
      _need(
        entry.value <= remaining,
        'OVER_ISSUE',
        'This quantity exceeds the approved remaining quantity.',
        status: 409,
      );
      _need(
        (stock['stock'] as num? ?? 10) >= entry.value,
        'INSUFFICIENT_STOCK',
        'Not enough stock is available.',
        status: 409,
      );
    }
    for (final entry in combined.entries) {
      final stock = _find('/materials', entry.key);
      stock['stock'] = (stock['stock'] as num? ?? 10) - entry.value;
      stock['issued'] = (stock['issued'] as num? ?? 0) + entry.value;
      stock['version']++;
      issued[entry.key] = (issued[entry.key] as int? ?? 0) + entry.value;
      _table('/materials/issues').insert(0, {
        'id': _id(),
        'name': '${stock['name']} · ${_employeeName(row['employeeId'])}',
        'requestId': row['id'],
        'employeeId': row['employeeId'],
        'employeeName': _employeeName(row['employeeId']),
        'materialId': entry.key,
        'materialName': stock['name'],
        'quantity': entry.value,
        'reason': body['note'] ?? body['reason'] ?? 'Approved material issue',
        'actorId': employeeId,
        'createdAt': _now().toUtc().toIso8601String(),
        'version': 1,
        'status': 'ISSUED',
      });
    }
    row['issuedQuantities'] = issued;
    row['fulfilledQuantity'] = issued.values.fold<int>(
      0,
      (sum, v) => sum + (v as int),
    );
    return items.every(
      (item) => (issued[item['materialId']] as int? ?? 0) == item['quantity'],
    );
  }

  DataResponse? _requestsCases(DataRequest r) {
    final body = r.body ?? {};
    if (['/requests/types', '/requests/admin/types'].contains(r.path) &&
        r.method == 'GET') {
      if (r.path.contains('/admin/')) {
        _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      }
      return _page(
        _requestTypes.where((t) => _admin || t['active'] == true),
        r,
      );
    }
    if (r.path == '/requests/admin/types' && r.method == 'POST' ||
        RegExp(r'^/requests/admin/types/[^/]+$').hasMatch(r.path) &&
            r.method == 'PATCH') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      final row = r.method == 'POST'
          ? <String, dynamic>{'id': _id(), 'version': 0}
          : _requestTypes.firstWhere(
              (row) => row['id'] == r.path.split('/').last,
            );
      if (r.method == 'PATCH') _version(r, row);
      _need(
        (body['name'] as String? ?? '').trim().isNotEmpty,
        'VALIDATION_ERROR',
        'Enter a policy name.',
      );
      final code = body['code'] ?? row['code'];
      _need(
        code is String && RegExp(r'^[A-Z][A-Z0-9_]{2,39}$').hasMatch(code),
        'VALIDATION_ERROR',
        'Use a unique uppercase category code with 3–40 letters, numbers or underscores.',
      );
      _need(
        !_requestTypes.any(
          (type) => type['code'] == code && type['id'] != row['id'],
        ),
        'POLICY_EXISTS',
        'A policy already exists for this category.',
        status: 409,
      );
      row.addAll({
        'name': body['name'],
        'code': code,
        'requiresAttachment': body['requiresAttachment'] == true,
        'active': body['active'] == true,
        'status': body['active'] == true ? 'ACTIVE' : 'INACTIVE',
      });
      row['version']++;
      if (r.method == 'POST') _requestTypes.add(row);
      _auditAction('REQUEST_POLICY_UPDATED', row['id']);
      return _ok(
        row,
        status: r.method == 'POST' ? 201 : 200,
        etag: '"${row['version']}"',
      );
    }
    if (r.path == '/materials/admin' && r.method == 'GET') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      return _page(
        _table('/materials').map(
          (row) => <String, dynamic>{
            ...row,
            'stock': row['stock'] ?? 10,
            'issued': row['issued'] ?? 0,
          },
        ),
        r,
      );
    }
    final receipt = RegExp(r'^/materials/admin/([^/]+)/receive$')
        .firstMatch(r.path);
    if (receipt != null && r.method == 'POST') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      _reason(body);
      final row = _find('/materials', receipt[1]!);
      _version(r, row);
      final quantity = body['quantity'];
      _need(
        quantity is num &&
            quantity % 1 == 0 &&
            quantity > 0 &&
            quantity <= 100000,
        'VALIDATION_ERROR',
        'Receive a positive whole quantity.',
      );
      row['stock'] = (row['stock'] as num? ?? 10) + quantity;
      row['version']++;
      _auditAction('STOCK_RECEIVED', row['id']);
      return _ok(row, etag: '"${row['version']}"');
    }
    if (r.path == '/materials/issues' && r.method == 'GET') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      return _page(_table('/materials/issues'), r);
    }
    if (r.path == '/requests/approved-materials' && r.method == 'GET') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      final rows = <JsonMap>[];
      for (final request in _table('/requests').where(
        (row) => row['status'] == 'APPROVED' && row['type'] == 'MATERIAL',
      )) {
        for (final item in request['items'] as List? ?? []) {
          final material = _find('/materials', item['materialId']);
          final issued =
              (request['issuedQuantities'] as Map?)?[item['materialId']]
                  as int? ??
              0;
          if ((item['quantity'] as num) > issued) {
            rows.add({
              ...request,
              'id': '${request['id']}--${item['materialId']}',
              'requestId': request['id'],
              'name': '${request['title']} · ${material['name']}',
              'materialId': item['materialId'],
              'materialName': material['name'],
              'quantity': item['quantity'],
              'fulfilledQuantity': issued,
              'remainingQuantity': (item['quantity'] as num) - issued,
              'etag': '"${request['version']}"',
            });
          }
        }
      }
      return _page(rows, r);
    }
    if (r.path == '/requests/admin/approval-chains' && r.method == 'GET') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      return _page(_table('/requests/approval-chains'), r);
    }
    if (r.path == '/requests/admin/approval-chains' && r.method == 'POST' ||
        r.path.startsWith('/requests/admin/approval-chains/') &&
            r.method == 'PATCH') {
      _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
      final row = r.method == 'POST'
          ? <String, dynamic>{'id': _id(), 'version': 0}
          : _find('/requests/approval-chains', r.path.split('/').last);
      if (r.method == 'PATCH') {
        _version(r, row);
        _reason(body);
      }
      final type = body['requestType'] ?? row['requestType'];
      _need(
        _requestTypes.any(
          (policy) => policy['code'] == type && policy['active'] == true,
        ),
        'VALIDATION_ERROR',
        'Choose an available request category.',
      );
      final manager = _person(body['managerId']);
      _need(
        manager['status'] == 'ACTIVE',
        'INACTIVE_REVIEWER',
        'Select an active reviewer.',
      );
      _need(
        !_table('/requests/approval-chains')
            .any((c) => c['requestType'] == type && c['id'] != row['id']),
        'CHAIN_EXISTS',
        'Edit the existing chain for this request type.',
        status: 409,
      );
      row.addAll({
        'name': body['name'],
        'requestType': type,
        'managerId': manager['id'],
        'managerName': manager['name'],
        'requireHr': body['requireHr'] == true,
        'status': 'ACTIVE',
      });
      row['version']++;
      if (r.method == 'POST') _table('/requests/approval-chains').add(row);
      _auditAction('APPROVAL_CHAIN_UPDATED', row['id']);
      return _ok(
        row,
        status: r.method == 'POST' ? 201 : 200,
        etag: '"${row['version']}"',
      );
    }
    final comment = RegExp(r'^/requests/([^/]+)/comments$').firstMatch(r.path);
    if (comment != null && r.method == 'POST') {
      final row = _find('/requests', comment[1]!);
      _need(
        _visible(row),
        'FORBIDDEN',
        'This request is outside your permitted scope.',
        status: 403,
      );
      _version(r, row);
      final text = body['text'] ?? body['note'];
      _need(
        text is String && text.trim().length >= 5 && text.length <= 2000,
        'VALIDATION_ERROR',
        'Enter a comment between 5 and 2,000 characters.',
      );
      (row['comments'] as List? ?? (row['comments'] = [])).add({
        'actor': profile['name'],
        'text': text,
        'at': _now().toUtc().toIso8601String(),
      });
      row['version']++;
      _auditAction('REQUEST_COMMENTED', row['id']);
      return _ok(row, etag: '"${row['version']}"');
    }
    return null;
  }
}
