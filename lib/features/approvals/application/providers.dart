import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/data/api_client.dart';

import '../data/delegation_repository.dart';
import '../domain/delegation.dart';

final delegationRepositoryProvider = Provider<DelegationRepository>(
  (ref) => DelegationRepository(ref.watch(clientProvider) as ApiClient),
);
final delegationsProvider =
    FutureProvider.autoDispose<List<ApprovalDelegation>>(
      (ref) => ref.watch(delegationRepositoryProvider).list(),
    );
