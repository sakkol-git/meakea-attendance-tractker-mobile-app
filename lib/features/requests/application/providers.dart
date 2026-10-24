import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/repository.dart';

final requestsRepositoryProvider = Provider<RequestsRepository>(
  (ref) => throw StateError('Requests composition is required.'),
);
