import 'cases.dart';
import '../features/notifications/application/push.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/app/providers.dart';

String message(Object e) => e is DataFailure
    ? switch (e.status) {
        401 => 'Your session expired. Please sign in again.',
        403 => 'You do not have permission to perform this action.',
        412 => 'This record changed. Refresh it before making a decision.',
        _ => e.message,
      }
    : 'Something went wrong. Please try again.';
void refreshFeatures(Ref ref) {
  ref.invalidate(caseRowsProvider);
  ref.invalidate(caseOptionsProvider);
  ref.invalidate(pushRegistrationProvider);
  ref.invalidate(shiftOptionsProvider);
  ref.invalidate(shiftAssignmentsProvider);
  ref.invalidate(todayProvider);
  ref.invalidate(sessionsProvider);
  ref.invalidate(teamAttendanceProvider);
  ref.invalidate(balancesProvider);
  ref.invalidate(recordsProvider);
  ref.invalidate(detailProvider);
  ref.invalidate(inboxProvider);
  ref.invalidate(collectionProvider);
  ref.invalidate(approvalProvider);
  ref.invalidate(reportProvider);
}

final cacheStaleProvider = StreamProvider<bool>(
  (ref) => ref.watch(clientProvider).staleChanges,
);

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
