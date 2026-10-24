import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrflow_mobile/features/attendance/domain/models.dart';

import '../domain/repository.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => throw StateError('Attendance composition is required.'),
);
final todayProvider = FutureProvider.autoDispose<AttendanceDay>(
  (ref) => ref.watch(attendanceRepositoryProvider).today(),
);
final sessionsProvider = FutureProvider.autoDispose<List<WorkSession>>(
  (ref) => ref.watch(attendanceRepositoryProvider).sessions(),
);

final teamAttendanceProvider = FutureProvider.autoDispose<List<WorkSession>>(
  (ref) => ref.watch(attendanceRepositoryProvider).sessions(team: true),
);
