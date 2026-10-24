import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repository.dart';

final operationsRepositoryProvider = Provider<OperationsRepository>(
  (ref) => throw StateError('Operations composition is required.'),
);
