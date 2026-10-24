import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrflow_mobile/features/leave/domain/models.dart';

import '../domain/repository.dart';

final leaveRepositoryProvider = Provider<LeaveRepository>(
  (ref) => throw StateError('Leave composition is required.'),
);
final balancesProvider = FutureProvider.autoDispose<List<LeaveBalance>>(
  (ref) => ref.watch(leaveRepositoryProvider).balances(),
);
