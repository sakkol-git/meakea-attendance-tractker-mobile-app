import '../features/operations/data/repository.dart';
import '../features/operations/application/providers.dart';
import '../features/attendance/application/evidence.dart';
import '../features/attendance/data/location_capture.dart';
import '../features/notifications/application/push.dart';
import '../features/notifications/data/push_device.dart';

import 'package:flutter_riverpod/misc.dart';

import 'providers.dart';
import '../features/settings/domain/preferences_gateway.dart';

import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/core/data/storage.dart';
import 'package:hrflow_mobile/features/identity/data/repository.dart';
import 'package:hrflow_mobile/features/attendance/data/repository.dart';
import 'package:hrflow_mobile/features/leave/data/repository.dart';
import 'package:hrflow_mobile/features/requests/data/repository.dart';
import 'package:hrflow_mobile/features/notifications/data/repository.dart';
import 'package:hrflow_mobile/features/reporting/data/repository.dart';

List<Override> composeFeatures(
  ClientData client, {
  PreferencesGateway? preferences,
}) => [
  clientProvider.overrideWithValue(client),
  operationsRepositoryProvider.overrideWithValue(
    OperationsDataRepository(client),
  ),
  locationCaptureProvider.overrideWithValue(
    client.isLocal ? DemoLocationCapture() : ForegroundLocationCapture(),
  ),
  pushDeviceProvider.overrideWithValue(
    client.isLocal ? DemoPushDevice() : FirebasePushDevice(),
  ),
  preferencesProvider.overrideWithValue(preferences ?? DevicePreferences()),
  identityRepositoryProvider.overrideWithValue(IdentityDataRepository(client)),
  attendanceRepositoryProvider.overrideWithValue(
    AttendanceDataRepository(client),
  ),
  leaveRepositoryProvider.overrideWithValue(LeaveDataRepository(client)),
  requestsRepositoryProvider.overrideWithValue(RequestsDataRepository(client)),
  notificationsRepositoryProvider.overrideWithValue(
    NotificationsDataRepository(client),
  ),
  reportingRepositoryProvider.overrideWithValue(
    ReportingDataRepository(client),
  ),
];
