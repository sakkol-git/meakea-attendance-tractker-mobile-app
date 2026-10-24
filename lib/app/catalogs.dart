import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/protocol.dart';
import '../shared/domain/resource_gateway.dart';
import 'providers.dart';

final collectionProvider = FutureProvider.autoDispose
    .family<List<JsonMap>, String>((ref, path) {
      final ResourceGateway repository = path.startsWith('/leave')
          ? ref.watch(leaveRepositoryProvider)
          : path.startsWith('/materials') || path.startsWith('/requests')
          ? ref.watch(requestsRepositoryProvider)
          : ref.watch(identityRepositoryProvider);
      return repository.collection(path);
    });
