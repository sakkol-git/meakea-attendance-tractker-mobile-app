import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrflow_mobile/core/protocol.dart';

import '../domain/repository.dart';
import '../../identity/application/session.dart';

final reportingRepositoryProvider = Provider<ReportingRepository>(
  (ref) => throw StateError('Reporting composition is required.'),
);
final reportProvider = FutureProvider.autoDispose<JsonMap>((ref) async {
  final local = ref.watch(clientProvider).isLocal;
  final body = await ref
      .watch(reportingRepositoryProvider)
      .get(local ? '/reports/dashboard' : '/reports/attendance/summary');
  if (body is! Map<String, dynamic>) {
    throw const DataFailure(
      0,
      'CONTRACT_MISMATCH',
      'The report response is invalid.',
    );
  }
  if (!local && (body['totalCount'] is! int || body['records'] is! List)) {
    throw const DataFailure(
      0,
      'CONTRACT_MISMATCH',
      'The attendance report response is invalid.',
    );
  }
  return body;
});
