import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrflow_mobile/features/leave/domain/models.dart';

import '../domain/repository.dart';

final leaveRepositoryProvider = Provider<LeaveRepository>(
  (ref) => throw StateError('Leave composition is required.'),
);
final balancesProvider = FutureProvider.autoDispose<List<LeaveBalance>>(
  (ref) => ref.watch(leaveRepositoryProvider).balances(),
);

typedef LeavePreviewQuery = ({
  String typeId,
  String from,
  String to,
  String halfDay,
});
final leavePreviewProvider = FutureProvider.autoDispose
    .family<LeavePreview, LeavePreviewQuery>(
      (ref, query) => ref
          .watch(leaveRepositoryProvider)
          .preview(query.typeId, query.from, query.to, query.halfDay),
    );
