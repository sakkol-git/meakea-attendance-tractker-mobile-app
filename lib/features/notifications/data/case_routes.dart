import 'package:hrflow_mobile/core/data/case_repository.dart';

const notificationsCaseRoutes = <String, CaseRoute>{
  'notifications.devices': CaseRoute(
    '/notifications/devices',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'notifications.device.register': CaseRoute(
    '/notifications/devices',
    method: 'POST',
    versioned: false,
    single: false,
  ),
  'notifications.device.remove': CaseRoute(
    '/notifications/devices/{id}',
    method: 'DELETE',
    versioned: true,
    single: false,
  ),
  'notifications.delivery': CaseRoute(
    '/notifications/delivery-status/me',
    method: 'GET',
    versioned: false,
    single: false,
  ),
};
