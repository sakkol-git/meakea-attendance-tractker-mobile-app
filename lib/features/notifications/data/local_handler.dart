part of '../../../core/demo/local_service.dart';

extension NotificationsDemo on LocalDataSource {
  DataResponse? _handleNotifications(DataRequest r) {
    final caseResult = _notificationsCases(r);
    if (caseResult != null) return caseResult;
    final body = r.body ?? {};
    if (r.path == '/notifications/preferences') {
      if (r.method == 'PUT') {
        _rows['/preferences/$employeeId'] = [body];
        return _ok(body);
      }
      return _ok(
        _rows['/preferences/$employeeId']?.firstOrNull ??
            {'approvals': true, 'attendance': true, 'announcements': true},
      );
    }
    if (r.path == '/notifications' && r.method == 'GET') {
      return _page(
        populate
            ? _notifications.where((v) => v['employeeId'] == employeeId)
            : _notifications,
        r,
      );
    }
    if (r.path == '/notifications/read-all' && r.method == 'POST') {
      for (final n in _notifications.where(
        (n) => n['employeeId'] == employeeId,
      )) {
        n['read'] = true;
      }
      return _ok(null, status: 204);
    }
    final notificationMatch = RegExp(r'^/notifications/([^/]+)/read$')
        .firstMatch(r.path);
    if (notificationMatch != null && r.method == 'POST') {
      final n = _notifications
          .where(
            (n) =>
                n['id'] == notificationMatch[1] &&
                n['employeeId'] == employeeId,
          )
          .firstOrNull;
      _need(n != null, 'NOT_FOUND', 'Notification not found.', status: 404);
      n!['read'] = true;
      return _ok(n);
    }
    return null;
  }
}
