import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrflow_mobile/core/protocol.dart';

import '../domain/repository.dart';

final reportingRepositoryProvider = Provider<ReportingRepository>(
  (ref) => throw StateError('Reporting composition is required.'),
);
final reportProvider = FutureProvider.autoDispose<JsonMap>(
  (ref) async => Map<String, dynamic>.from(
    await ref.watch(reportingRepositoryProvider).get('/reports/dashboard'),
  ),
);
