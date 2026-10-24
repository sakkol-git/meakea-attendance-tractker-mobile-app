part of '../../../core/demo/local_service.dart';

extension NotificationCases on LocalDataSource {
  DataResponse? _notificationsCases(DataRequest r) {
    final rows = _table('/notification-devices'), b = r.body ?? {};
    if (r.path == '/notifications/devices' && r.method == 'GET') {
      return _page(
        rows
            .where((v) => v['employeeId'] == employeeId)
            .map((v) => {...v}..remove('token')),
        r,
      );
    }
    if (r.path == '/notifications/devices' && r.method == 'POST') {
      _need(
        (b['token'] as String? ?? '').length >= 10,
        'VALIDATION_ERROR',
        'A valid device registration token is required.',
      );
      final existing = rows
          .where(
            (v) => v['token'] == b['token'] && v['employeeId'] == employeeId,
          )
          .firstOrNull;
      if (existing != null) return _ok({...existing}..remove('token'));
      final row = <String, dynamic>{
        'id': _id(),
        'title': b['name'] ?? 'This device',
        'employeeId': employeeId,
        'platform': b['platform'] ?? 'DEMO',
        'token': b['token'],
        'status': 'REGISTERED',
        'lastSeenAt': _now().toIso8601String(),
        'version': 1,
      };
      rows.add(row);
      return _ok({...row}..remove('token'), status: 201, etag: '"1"');
    }
    final m = RegExp(r'^/notifications/devices/([^/]+)$').firstMatch(r.path);
    if (m != null && r.method == 'DELETE') {
      _reason(b);
      final row = rows
          .where((v) => v['id'] == m[1] && v['employeeId'] == employeeId)
          .firstOrNull;
      _need(row != null, 'NOT_FOUND', 'Device not found.', status: 404);
      _version(r, row!);
      rows.remove(row);
      return _ok(null, status: 204);
    }
    if (r.path == '/notifications/delivery-status/me' && r.method == 'GET') {
      return _page(
        _notifications
            .where((n) => n['employeeId'] == employeeId)
            .map(
              (n) => {
                ...n,
                'status': 'IN_APP_AVAILABLE',
                'channel': 'IN_APP',
                'message': 'Available in your inbox. No push provider is connected to this demo.',
              },
            ),
        r,
      );
    }
    return null;
  }
}
