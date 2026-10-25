import 'cases.dart';
import '../features/notifications/application/push.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/data/pending_commands.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/core/data/cache/cached_source.dart';

String message(Object e) {
  if (e is! DataFailure) return 'Something went wrong. Please try again.';
  final detail = switch (e.status) {
    401 => 'Your session expired. Please sign in again.',
    403 => 'You do not have permission to perform this action.',
    412 => 'This record changed. Refresh it before making a decision.',
    _ => e.message,
  };
  return e.traceId == null ? detail : '$detail Reference: ${e.traceId}.';
}

enum WriteFailureKind { conflict, failed, unknown }

WriteFailureKind writeFailureKind(Object error) => error is DataFailure
    ? error.status == 412
          ? WriteFailureKind.conflict
          : {'TIMEOUT', 'NETWORK_ERROR'}.contains(error.code)
          ? WriteFailureKind.unknown
          : WriteFailureKind.failed
    : WriteFailureKind.failed;
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
final staleResourcesProvider = StreamProvider<List<StaleResource>>((ref) {
  final client = ref.watch(clientProvider);
  return client is ClientData ? client.staleResources : const Stream.empty();
});

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final pendingCommandKeysProvider = Provider<PendingCommandKeys>((ref) {
  final client = ref.watch(clientProvider);
  if (client is! ClientData) {
    throw StateError('Persistent command keys require ClientData.');
  }
  return PendingCommandKeys(client.secrets, client.namespace);
});
