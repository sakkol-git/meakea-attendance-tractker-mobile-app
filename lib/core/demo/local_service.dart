import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hrflow_mobile/core/protocol.dart';
part '../../features/identity/data/local_handler.dart';
part '../../features/operations/data/local_handler.dart';
part '../../features/identity/data/case_local.dart';
part '../../features/leave/data/local_handler.dart';
part '../../features/leave/data/case_local.dart';
part '../../features/notifications/data/local_handler.dart';
part '../../features/notifications/data/case_local.dart';
part '../../features/attendance/data/local_handler.dart';
part '../../features/attendance/data/case_local.dart';
part '../../features/reporting/data/local_handler.dart';
part '../../features/reporting/data/case_local.dart';
part '../../features/attachments/data/local_handler.dart';
part '../../features/workflows/data/local_handler.dart';
part '../../features/requests/data/local_handler.dart';
part '../../features/requests/data/case_local.dart';

/// Synthetic service: domain rules here are demonstrable assumptions, not server security.
class LocalDataSource implements DataSource {
  @override
  String get mode => 'local';
  final JsonMap _seed;
  final DateTime Function() _now;
  final bool populate;
  final Map<String, List<JsonMap>> _rows = {};
  final Map<String, ({String fingerprint, DataResponse response})> _receipts =
      {};
  final List<JsonMap> _sessions = [], _notifications = [], _audit = [];
  final Map<String, JsonMap> _files = {};
  String _actor = 'EMPLOYEE';
  int _sequence = 100;
  Future<void> Function(JsonMap)? onChanged;
  Future<void> _serial = Future.value();
  LocalDataSource(
    JsonMap seed, {
    DateTime Function()? now,
    this.populate = false,
  }) : _seed = copyJson(seed) as JsonMap,
       _now = now ?? DateTime.now {
    reset();
  }
  static const roles = ['EMPLOYEE', 'MANAGER', 'HR_ADMIN', 'OWNER'];
  String get employeeId => !populate
      ? 'demo-employee'
      : switch (_actor) {
          'MANAGER' => 'demo-manager',
          'HR_ADMIN' => 'demo-hr',
          'OWNER' => 'demo-owner',
          _ => 'demo-employee',
        };
  bool get _manages => _actor != 'EMPLOYEE';
  bool get _admin => ['HR_ADMIN', 'OWNER'].contains(_actor);
  DateTime get _companyNow => _now().toUtc().add(const Duration(hours: 7));
  String get today => _companyNow.toIso8601String().substring(0, 10);
  String _id() => 'demo-${++_sequence}';
  void setDemoRole(String role) {
    if (!roles.contains(role)) throw ArgumentError.value(role, 'role');
    _actor = role;
  }

  JsonMap get profile => {
    ..._seed['profile'] as Map,
    'employeeId': employeeId,
    'userId': employeeId,
    'roles': [_actor],
    'name': switch (_actor) {
      'MANAGER' => 'Chan Sopheak',
      'HR_ADMIN' => 'Kim Sreyneang',
      'OWNER' => 'Vann Rith',
      _ => 'Sok Dara',
    },
    'email': '${employeeId.replaceFirst('demo-', '')}@hrflow.demo',
    'organization': _company['name'],
    'department': _admin ? 'People & Culture' : 'Product & Engineering',
    'position': switch (_actor) {
      'MANAGER' => 'Engineering manager',
      'HR_ADMIN' => 'People operations',
      'OWNER' => 'Company owner',
      _ => 'Product designer',
    },
    'phone': '+855 12 345 678',
    'timezone': 'Asia/Phnom_Penh',
    ...?_rows['/profile-overrides']
        ?.where((v) => v['employeeId'] == employeeId)
        .firstOrNull,
  };
  void reset() {
    _rows.clear();
    _receipts.clear();
    _sessions.clear();
    _notifications.clear();
    _audit.clear();
    _files.clear();
    _actor = 'EMPLOYEE';
    _sequence = 100;
    for (final resource in _seed['resources'] as List) {
      _rows[resource['path'] as String] = (resource['records'] as List)
          .map((v) => JsonMap.from(v))
          .toList();
    }
    _rows['/employees'] = [
      ...(_seed['employees'] as List).map(
        (v) => <String, dynamic>{
          ...v as Map,
          'email': '${v['id']}@hrflow.demo',
          'position': 'Product team',
          'managerId': v['id'] == 'demo-manager' ? null : 'demo-manager',
          'status': 'ACTIVE',
        },
      ),
    ];
    if (populate) {
      _table('/employees').addAll([
        {
          'id': 'demo-hr',
          'name': 'Kim Sreyneang',
          'email': 'hr@hrflow.demo',
          'position': 'People operations',
          'department': 'People & Culture',
          'departmentId': 'people',
          'positionId': 'designer',
          'managerId': 'demo-owner',
          'status': 'ACTIVE',
          'roles': ['HR_ADMIN'],
          'version': 1,
        },
        {
          'id': 'demo-owner',
          'name': 'Vann Rith',
          'email': 'owner@hrflow.demo',
          'position': 'Company owner',
          'department': 'People & Culture',
          'departmentId': 'people',
          'positionId': 'designer',
          'managerId': null,
          'status': 'ACTIVE',
          'roles': ['OWNER'],
          'version': 1,
        },
      ]);
    }
    _rows['/departments'] = [
      {'id': 'product', 'name': 'Product & Engineering', 'version': 1},
      {'id': 'people', 'name': 'People & Culture', 'version': 1},
    ];
    _rows['/positions'] = [
      {'id': 'designer', 'name': 'Product designer', 'version': 1},
      {'id': 'engineer', 'name': 'Software engineer', 'version': 1},
    ];
    _rows['/shifts'] = [
      {
        'id': 'shift-standard',
        'name': 'Standard workday',
        'startTime': '08:30',
        'endTime': '17:30',
        'days': 'Monday–Friday',
        'version': 1,
      },
    ];
    _rows['/holidays'] = [
      {
        'id': 'holiday-1',
        'name': 'Independence Day',
        'date': '2026-11-09',
        'kind': 'PUBLIC',
        'version': 1,
      },
    ];
    _rows['/leave/types'] = [
      {
        'id': 'annual',
        'name': 'Annual leave',
        'entitled': 18,
        'paid': true,
        'allowHalfDay': true,
        'version': 1,
      },
      {
        'id': 'sick',
        'name': 'Sick leave',
        'entitled': 10,
        'paid': true,
        'allowHalfDay': true,
        'version': 1,
      },
      {
        'id': 'personal',
        'name': 'Personal leave',
        'entitled': 5,
        'paid': false,
        'allowHalfDay': true,
        'version': 1,
      },
    ];
    _rows['/materials'] = [
      {
        'id': 'monitor',
        'name': 'External monitor',
        'unit': 'item',
        'version': 1,
      },
      {'id': 'keyboard', 'name': 'Keyboard', 'unit': 'item', 'version': 1},
    ];
    _rows['/work-sites'] = [
      {
        'id': 'site-headquarters',
        'name': 'Headquarters',
        'latitude': 11.5564,
        'longitude': 104.9282,
        'radiusMeters': 200,
        'timezone': 'Asia/Phnom_Penh',
        'status': 'ACTIVE',
        'version': 1,
      },
    ];
    _rows['/exports'] = [];
    _rows['/shift-assignments'] = [];
    if (populate) _populate();
  }

  void _populate() {
    final earlier = _companyNow.subtract(const Duration(days: 4));
    for (var i = 1; i <= 4; i++) {
      final date = _companyNow.subtract(Duration(days: i));
      final start = DateTime.utc(
        date.year,
        date.month,
        date.day,
        1,
        30 + i * 2,
      );
      _sessions.add({
        'id': _id(),
        'employeeId': 'demo-employee',
        'checkInAt': start.toIso8601String(),
        'checkOutAt': start
            .add(const Duration(hours: 8, minutes: 15))
            .toIso8601String(),
        'source': i == 1 ? 'INFERRED' : 'TAP',
        'confirmStatus': i == 1 ? 'PENDING' : 'NONE',
        'version': 1,
      });
    }
    _rows['/leave/requests']!.addAll([
      {
        'id': 'leave-approved',
        'employeeId': 'demo-employee',
        'employeeName': 'Sok Dara',
        'title': 'Annual leave',
        'leaveTypeId': 'annual',
        'typeName': 'Annual leave',
        'startDate': earlier.toIso8601String().substring(0, 10),
        'endDate': earlier.toIso8601String().substring(0, 10),
        'days': 1.0,
        'reason': 'Family appointment',
        'status': 'APPROVED',
        'version': 1,
        'decisions': [
          {
            'actor': 'Chan Sopheak',
            'action': 'APPROVED',
            'note': 'Enjoy your day.',
            'at': earlier.toIso8601String(),
          },
        ],
      },
      {
        'id': 'leave-pending',
        'employeeId': 'demo-employee',
        'employeeName': 'Sok Dara',
        'title': 'Personal leave',
        'leaveTypeId': 'personal',
        'typeName': 'Personal leave',
        'startDate': _companyNow
            .add(const Duration(days: 7))
            .toIso8601String()
            .substring(0, 10),
        'endDate': _companyNow
            .add(const Duration(days: 7))
            .toIso8601String()
            .substring(0, 10),
        'days': 1.0,
        'reason': 'Personal appointment',
        'status': 'PENDING',
        'version': 1,
        'decisions': [],
      },
    ]);
    _rows['/requests']!.add({
      'id': 'request-draft',
      'items': [
        {'materialId': 'monitor', 'quantity': 1},
      ],
      'quantity': 1,
      'employeeId': 'demo-employee',
      'employeeName': 'Sok Dara',
      'title': 'Workspace upgrade',
      'type': 'MATERIAL',
      'description': 'An external monitor for design reviews.',
      'reason': 'An external monitor for design reviews.',
      'status': 'DRAFT',
      'version': 1,
      'decisions': [],
      'attachments': [],
    });
    _notifications.add({
      'id': 'welcome',
      'employeeId': 'demo-employee',
      'title': 'Welcome to your workspace',
      'body': 'Your attendance, time off and requests, together in one place.',
      'read': false,
      'createdAt': _now().toIso8601String(),
    });
  }

  JsonMap snapshot() => {
    'schema': 2,
    'rows': _rows,
    'sessions': _sessions,
    'notifications': _notifications,
    'audit': _audit,
    'files': _files,
    'sequence': _sequence,
    'receipts': {
      for (final entry in _receipts.entries)
        entry.key: {
          'fingerprint': entry.value.fingerprint,
          'status': entry.value.response.status,
          'data': entry.value.response.data,
          'etag': entry.value.response.etag,
        },
    },
  };
  void restore(JsonMap saved) {
    if (saved['schema'] != 2) {
      throw const FormatException('Unsupported demo schema');
    }
    _rows.clear();
    for (final entry in (saved['rows'] as Map).entries) {
      _rows[entry.key as String] = (entry.value as List)
          .map((r) => JsonMap.from(r))
          .toList();
    }
    for (final person in _table('/employees')) {
      if (person['managerId'] == person['id']) person['managerId'] = null;
    }
    _sessions
      ..clear()
      ..addAll((saved['sessions'] as List).map((r) => JsonMap.from(r)));
    _notifications
      ..clear()
      ..addAll((saved['notifications'] as List).map((r) => JsonMap.from(r)));
    _audit
      ..clear()
      ..addAll((saved['audit'] as List).map((r) => JsonMap.from(r)));
    _files
      ..clear()
      ..addAll(
        (saved['files'] as Map).map(
          (k, v) => MapEntry(k as String, JsonMap.from(v)),
        ),
      );
    _sequence = saved['sequence'] as int;
    _receipts.clear();
    for (final entry in (saved['receipts'] as Map? ?? {}).entries) {
      final value = entry.value as Map;
      _receipts[entry.key as String] = (
        fingerprint: value['fingerprint'] as String,
        response: DataResponse(
          value['status'] as int,
          value['data'],
          etag: value['etag'] as String?,
        ),
      );
    }
  }

  @override
  Future<DataResponse> send(DataRequest r) {
    final result = _serial.then((_) => _send(r));
    _serial = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<DataResponse> _send(DataRequest r) async {
    validateRequest(r);
    if (!populate && r.query.isNotEmpty) {
      throw const DataFailure(
        501,
        'DEMO_NOT_IMPLEMENTED',
        'Local query filters are not implemented yet.',
      );
    }
    final scope = '$_actor:${r.method}:${r.path}:${r.idempotencyKey}';
    final canonical = canonicalJson({
      'body': r.body,
      'query': r.query,
      'ifMatch': r.ifMatch,
    });
    final fingerprint = sha256.convert(utf8.encode(canonical)).toString();
    final previous = r.method == 'POST' ? _receipts[scope] : null;
    if (previous != null) {
      if (previous.fingerprint != fingerprint &&
          previous.fingerprint != canonical) {
        throw const DataFailure(
          409,
          'IDEMPOTENCY_CONFLICT',
          'This key was already used for a different command.',
        );
      }
      return _copy(previous.response);
    }
    final before = copyJson(snapshot()) as JsonMap;
    try {
      final response = _dispatch(r);
      if (r.method == 'POST') {
        _receipts[scope] = (
          fingerprint: fingerprint,
          response: _copy(response),
        );
      }
      if (r.method != 'GET' && onChanged != null) {
        await onChanged!(copyJson(snapshot()) as JsonMap);
      }
      return _copy(response);
    } catch (_) {
      restore(before);
      rethrow;
    }
  }

  DataResponse _copy(DataResponse r) =>
      DataResponse(r.status, copyJson(r.data), etag: r.etag);
  DataResponse _ok(dynamic value, {int status = 200, String? etag}) =>
      DataResponse(status, value, etag: etag);
  DataResponse _page(Iterable<JsonMap> values, DataRequest r) {
    var list = values.toList();
    if (r.query['status'] != null) {
      list = list.where((v) => v['status'] == r.query['status']).toList();
    }
    if (r.query['search'] != null) {
      final q = r.query['search']!.toLowerCase();
      list = list
          .where((v) => v.values.join(' ').toLowerCase().contains(q))
          .toList();
    }
    for (final bound in ['from', 'to']) {
      final date = r.query[bound];
      if (date == null || date.isEmpty) continue;
      list = list.where((row) {
        final value = (row['workDate'] ?? row['date'] ?? row['createdAt'])
            ?.toString();
        if (value == null) return true;
        final day = value.substring(0, value.length < 10 ? value.length : 10);
        return bound == 'from'
            ? day.compareTo(date) >= 0
            : day.compareTo(date) <= 0;
      }).toList();
    }
    final total = list.length;
    final page = int.tryParse(r.query['page'] ?? '0') ?? 0,
        size = int.tryParse(r.query['size'] ?? '$total') ?? total;
    _need(
      page >= 0 && size >= 0 && size <= 1000,
      'VALIDATION_ERROR',
      'Invalid page or size.',
    );
    final selected = r.query.containsKey('size')
        ? list.skip(page * size).take(size).toList()
        : list;
    return _ok({'items': selected, 'total': total, 'page': page, 'size': size});
  }

  void _need(bool condition, String code, String message, {int status = 422}) {
    if (!condition) throw DataFailure(status, code, message);
  }

  void _version(DataRequest r, JsonMap row) {
    _need(
      r.ifMatch != null,
      'VERSION_REQUIRED',
      'Read the record and supply its ETag.',
      status: 428,
    );
    _need(
      r.ifMatch == '"${row['version']}"',
      'STALE_VERSION',
      'This record changed. Refresh before deciding.',
      status: 412,
    );
  }

  void _auditAction(String action, String id) {
    _audit.insert(0, {
      'id': _id(),
      'action': action,
      'actor': profile['name'],
      'entityId': id,
      'at': _now().toUtc().toIso8601String(),
    });
  }

  List<JsonMap> _table(String path) => _rows.putIfAbsent(path, () => []);
  String _employeeName(String id) =>
      _table('/employees').where((row) => row['id'] == id).firstOrNull?['name']
          as String? ??
      (id == employeeId ? profile['name'] as String : 'Employee');
  JsonMap _person(String id) {
    final row = _table('/employees')
        .where((row) => row['id'] == id)
        .firstOrNull;
    _need(row != null, 'NOT_FOUND', 'Employee not found.', status: 404);
    return row!;
  }

  void _reason(JsonMap body) => _need(
    (body['reason'] as String? ?? body['note'] as String? ?? '')
            .trim()
            .length >=
        5,
    'VALIDATION_ERROR',
    'Give a clear reason with at least five characters.',
  );
  JsonMap _find(String path, String id) {
    final row = _table(path).where((row) => row['id'] == id).firstOrNull;
    _need(row != null, 'NOT_FOUND', 'Record not found.', status: 404);
    return row!;
  }

  int _units(Object? value) {
    final raw = value?.toString() ?? '';
    _need(
      RegExp(r'^-?\d+(?:\.\d{1,2})?$').hasMatch(raw),
      'VALIDATION_ERROR',
      'Use at most two decimal places.',
    );
    final negative = raw.startsWith('-');
    final parts = raw.replaceFirst('-', '').split('.');
    final amount =
        int.parse(parts[0]) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
    return negative ? -amount : amount;
  }

  bool _visible(JsonMap row) =>
      !populate ||
      row['employeeId'] == null ||
      row['employeeId'] == employeeId ||
      _admin ||
      (_actor == 'MANAGER' &&
          (_table('/employees').any(
                (person) =>
                    person['id'] == row['employeeId'] &&
                    person['managerId'] == employeeId,
              ) ||
              row['currentApproverId'] == employeeId));
  List<JsonMap> _own(List<JsonMap> rows) => !populate
      ? rows.where((r) => r['supersededBy'] == null).toList()
      : rows
            .where(
              (r) => r['employeeId'] == employeeId && r['supersededBy'] == null,
            )
            .toList();
  bool _validDate(dynamic value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return false;
    }
    final parsed = DateTime.tryParse(value);
    return parsed != null && parsed.toIso8601String().substring(0, 10) == value;
  }

  DataResponse? _catalogue(DataRequest r, List<String> paths) {
    final body = r.body ?? {};
    for (final path in paths) {
      final rows = _rows[path]!;
      if (r.method == 'GET' && r.path == path) {
        if (path == '/employees') {
          _need(
            _manages,
            'FORBIDDEN',
            'Management access is required.',
            status: 403,
          );
        }
        return _page(rows, r);
      }
      if (r.path == path && r.method == 'POST') {
        _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
        if (path == '/departments' || path == '/positions') {
          _need(
            body.keys.every({'name'}.contains),
            'VALIDATION_ERROR',
            'This catalog edit contains an unsupported field.',
          );
        }
        _need(
          (body['name'] as String? ?? '').trim().isNotEmpty,
          'VALIDATION_ERROR',
          'A name is required.',
        );
        final row = <String, dynamic>{...body, 'id': _id(), 'version': 1};
        rows.add(row);
        _auditAction('CREATED', row['id']);
        return _ok(row, status: 201, etag: '"1"');
      }
      if (r.path.startsWith('$path/') && r.method == 'PATCH') {
        _need(_admin, 'FORBIDDEN', 'HR access is required.', status: 403);
        if (path == '/departments' || path == '/positions') {
          _need(
            body.keys.every({'name'}.contains),
            'VALIDATION_ERROR',
            'This catalog edit contains an unsupported field.',
          );
        }
        final row = rows
            .where((v) => v['id'] == r.path.substring(path.length + 1))
            .firstOrNull;
        _need(row != null, 'NOT_FOUND', 'Record not found.', status: 404);
        _version(r, row!);
        row.addAll(body);
        row['version']++;
        _auditAction('UPDATED', row['id']);
        return _ok(row, etag: '"${row['version']}"');
      }
    }
    return null;
  }

  DataResponse _dispatch(DataRequest r) {
    final result =
        _operationsCases(r) ??
        _handleIdentity(r) ??
        _handleLeave(r) ??
        _handleNotifications(r) ??
        _handleAttendance(r) ??
        _handleReporting(r) ??
        _handleAttachments(r) ??
        _handleRequests(r) ??
        _handleWorkflows(r);
    if (result != null) return result;
    throw const DataFailure(
      501,
      'DEMO_NOT_IMPLEMENTED',
      'This operation needs an agreed API contract.',
    );
  }

  @override
  void close() {}
}
