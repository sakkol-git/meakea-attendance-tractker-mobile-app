part of '../../../core/demo/local_service.dart';

extension WorkflowsDemo on LocalDataSource {
  void _validateCreate(String path, JsonMap body) {
    final reason =
        (body['reason'] as String? ?? body['description'] as String? ?? '')
            .trim();
    _need(
      reason.length >= 5,
      'VALIDATION_ERROR',
      'Please give a reason with at least 5 characters.',
    );
    switch (path) {
      case '/leave/requests':
        _validateLeave(path, body);
      case '/attendance/corrections':
        _validateAttendance(path, body);
      case '/requests':
        _validateRequests(path, body);
    }
  }

  DataResponse? _handleWorkflows(DataRequest r) {
    final body = r.body ?? {};
    for (final resource in _seed['resources'] as List) {
      final path = resource['path'] as String, rows = _rows[path]!;
      final isPending = r.path == '$path/pending';
      if (r.method == 'GET' && (r.path == resource['listPath'] || isPending)) {
        if (isPending) {
          _need(
            _manages,
            'FORBIDDEN',
            'Management access is required.',
            status: 403,
          );
        }
        return _page(
          isPending
              ? rows.where(
                  (v) =>
                      _visible(v) &&
                      v['status'] == 'PENDING' &&
                      (!populate || v['employeeId'] != employeeId),
                )
              : _own(rows),
          r,
        );
      }
      if (r.method == 'POST' && r.path == path) {
        _need(body.isNotEmpty, 'VALIDATION_ERROR', 'Provide request details.');
        final details = <String, dynamic>{...copyJson(body) as Map};
        if (populate) _validateCreate(path, details);
        final row = <String, dynamic>{
          ...details,
          'id': _id(),
          'employeeId': employeeId,
          'employeeName': profile['name'],
          'status': resource['initialStatus'],
          'version': 1,
          'createdAt': _now().toUtc().toIso8601String(),
          'decisions': [],
          'attachments': [],
        };
        rows.insert(0, row);
        if (populate && path == '/leave/requests') _leaveEntry(row, 'RESERVE');
        _auditAction('CREATED', row['id']);
        return _ok(row, status: 201, etag: '"1"');
      }
      if (!r.path.startsWith('$path/')) continue;
      final parts = r.path.substring(path.length + 1).split('/');
      if (parts.length > 2) continue;
      final row = rows
          .where((v) => v['id'] == parts[0] && _visible(v))
          .firstOrNull;
      _need(row != null, 'NOT_FOUND', 'Record not found.', status: 404);
      if (r.method == 'GET' && parts.length == 1) {
        return _ok({
          ...row!,
          if (populate && path == '/leave/requests')
            'canCancel':
                row['status'] == 'PENDING' ||
                (row['status'] == 'APPROVED' &&
                    (row['startDate'] as String).compareTo(today) > 0),
        }, etag: '"${row['version']}"');
      }
      if (r.method == 'PATCH' && parts.length == 1) {
        _need(
          row!['employeeId'] == employeeId && row['status'] == 'DRAFT',
          'FORBIDDEN',
          'Only your drafts can be edited.',
          status: 403,
        );
        _version(r, row);
        _need(
          body.keys.every(
            (key) => [
              'title',
              'reason',
              'description',
              'type',
              'items',
              'quantity',
              'startDate',
              'endDate',
              'fromTime',
              'toTime',
            ].contains(key),
          ),
          'INVALID_FIELD',
          'Only draft request details can be edited.',
        );
        final updated = <String, dynamic>{...row, ...body};
        if (populate) _validateRequests(path, updated);
        row.addAll(body);
        row['version']++;
        return _ok(row, etag: '"${row['version']}"');
      }
      final action = parts.length == 2 ? parts[1] : '';
      var transition = resource['transitions'][action];
      if (populate &&
          path == '/leave/requests' &&
          action == 'cancel' &&
          row!['status'] == 'APPROVED') {
        _need(
          (row['startDate'] as String).compareTo(today) > 0,
          'PAST_LEAVE',
          'Started leave requires an independent conflict review.',
          status: 409,
        );
        transition = {
          'roles': LocalDataSource.roles,
          'from': ['APPROVED'],
          'to': 'CANCELLED',
        };
      }
      if (r.method != 'POST' || transition == null) continue;
      _need(
        (transition['roles'] as List).contains(_actor) ||
            (populate &&
                ['submit', 'cancel'].contains(action) &&
                row!['employeeId'] == employeeId),
        'FORBIDDEN',
        'This role cannot perform this action.',
        status: 403,
      );
      _version(r, row!);
      _need(
        (transition['from'] as List).contains(row['status']),
        'INVALID_TRANSITION',
        'This action is unavailable in the current state.',
        status: 409,
      );
      if (populate) {
        if (['approve', 'reject', 'fulfill'].contains(action)) {
          _need(
            row['employeeId'] != employeeId,
            'SELF_APPROVAL',
            'You cannot decide your own request.',
            status: 403,
          );
        }
        if (['submit', 'cancel'].contains(action)) {
          _need(
            row['employeeId'] == employeeId,
            'FORBIDDEN',
            'Only the owner can change this request.',
            status: 403,
          );
        }
        if (action == 'reject') {
          _need(
            (body['note'] as String? ?? body['reason'] as String? ?? '')
                .trim()
                .isNotEmpty,
            'VALIDATION_ERROR',
            'Explain why this request is rejected.',
          );
        }
        if (action == 'approve' && row['approvalStage'] == 'HR') {
          _need(
            _admin,
            'FORBIDDEN',
            'This step requires HR approval.',
            status: 403,
          );
        }
      }
      if (populate && path == '/requests' && action == 'submit') {
        _validateRequests(path, row);
        final policy = _requestTypes
            .where((type) => type['code'] == row['type'])
            .firstOrNull;
        _need(
          policy != null && policy['active'] == true,
          'REQUEST_POLICY',
          'This request category is not available.',
        );
        _need(
          policy!['requiresAttachment'] != true ||
              (row['attachments'] as List).isNotEmpty,
          'ATTACHMENT_REQUIRED',
          'Add supporting evidence before submitting.',
        );
        _prepareRequestApproval(row);
      }
      if (populate &&
          path == '/requests' &&
          ['approve', 'reject'].contains(action)) {
        _checkRequestApprover(row);
      }
      if (populate && path == '/leave/requests' && action == 'approve') {
        final type = _find('/leave/types', row['leaveTypeId']);
        _need(
          type['requiresAttachment'] != true ||
              (row['attachments'] as List).isNotEmpty,
          'ATTACHMENT_REQUIRED',
          'Supporting evidence is required before approval.',
        );
      }
      if (populate &&
          action == 'approve' &&
          path == '/attendance/corrections') {
        final correctedIn = DateTime.parse(row['newCheckIn']);
        final correctedOut = DateTime.parse(row['newCheckOut']);
        final day = row['workDate'];
        final existing = _sessions
            .where(
              (session) =>
                  session['employeeId'] == row['employeeId'] &&
                  DateTime.parse(session['checkInAt'] ?? session['clockIn'])
                          .toUtc()
                          .add(const Duration(hours: 7))
                          .toIso8601String()
                          .substring(0, 10) ==
                      day,
            )
            .toList();
        _need(
          existing.every(
            (session) => (session['checkOutAt'] ?? session['clockOut']) != null,
          ),
          'OPEN_SESSION',
          'Close the active attendance session before approving a correction.',
          status: 409,
        );
        // The synthetic policy replaces that workday with one reviewed manual session.
        // Original values remain in the correction audit payload for demonstration.
        row['previousSessions'] = copyJson(existing);
        for (final session in existing) {
          session['supersededBy'] = row['id'];
        }
        _sessions.add({
          'id': _id(),
          'employeeId': row['employeeId'],
          'version': 1,
          'checkInAt': correctedIn.toUtc().toIso8601String(),
          'checkOutAt': correctedOut.toUtc().toIso8601String(),
          'source': 'MANUAL',
          'confirmStatus': 'NONE',
          'correctionId': row['id'],
        });
        _detectLeaveConflict(_sessions.last);
      }
      row['status'] = transition['to'];
      if (populate && path == '/leave/requests') {
        _leaveEntry(
          row,
          action == 'approve'
              ? 'APPROVE'
              : action == 'cancel'
              ? 'COMPENSATE'
              : 'RELEASE',
          reason: body['note'] ?? body['reason'],
        );
      }
      if (populate && path == '/requests' && action == 'fulfill') {
        row['status'] = _fulfillMaterial(row, body) ? 'FULFILLED' : 'APPROVED';
      }
      if (populate &&
          path == '/requests' &&
          action == 'approve' &&
          !_advanceRequestApproval(row)) {
        row['status'] = 'PENDING';
      }
      row['version']++;
      if (populate && path == '/leave/requests' && action == 'approve') {
        for (final session in _sessions.where(
          (s) =>
              s['employeeId'] == row['employeeId'] &&
              s['supersededBy'] == null &&
              s['confirmStatus'] != 'REJECTED',
        )) {
          _detectLeaveConflict(session);
        }
      }
      (row['decisions'] as List? ?? (row['decisions'] = [])).add({
        'actor': profile['name'],
        'action': action.toUpperCase(),
        'note': body['note'] ?? body['reason'] ?? '',
        'at': _now().toUtc().toIso8601String(),
      });
      _notifications.insert(0, {
        'id': _id(),
        'employeeId': row['employeeId'],
        'title':
            '${row['title'] ?? 'Request'} · ${row['status'].toString().toLowerCase()}',
        'body': body['note'] ?? 'Your request has been updated.',
        'read': false,
        'recordId': row['id'],
        'kind': path == '/leave/requests'
            ? 'leave'
            : path == '/requests'
            ? 'request'
            : 'correction',
        'createdAt': _now().toUtc().toIso8601String(),
      });
      _auditAction(action.toUpperCase(), row['id']);
      return _ok(row, etag: '"${row['version']}"');
    }
    return null;
  }
}
