import 'shift_use_cases.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrflow_mobile/features/identity/domain/models.dart';

import '../domain/repository.dart';

final identityRepositoryProvider = Provider<IdentityRepository>(
  (ref) => throw StateError('Identity composition is required.'),
);

final shiftOptionsProvider = FutureProvider.autoDispose<List<ShiftOption>>(
  (ref) => ref.watch(identityRepositoryProvider).shiftOptions(),
);
final shiftAssignmentsProvider = FutureProvider.autoDispose
    .family<List<ShiftAssignment>, String>(
      (ref, id) => ref.watch(identityRepositoryProvider).shiftAssignments(id),
    );
final shiftUseCasesProvider = Provider<ShiftUseCases>(
  (ref) => ShiftUseCases(ref.watch(identityRepositoryProvider)),
);
