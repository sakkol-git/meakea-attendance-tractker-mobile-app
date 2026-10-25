import '../core/protocol.dart';
import '../features/operations/application/providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/domain/cases.dart';
import 'providers.dart';

final caseGatewayProvider = Provider.family<CaseGateway, String>(
  (ref, module) => switch (module) {
    'operations' => ref.watch(operationsRepositoryProvider),
    'identity' => ref.watch(identityRepositoryProvider),
    'attendance' => ref.watch(attendanceRepositoryProvider),
    'leave' => ref.watch(leaveRepositoryProvider),
    'requests' => ref.watch(requestsRepositoryProvider),
    'notifications' => ref.watch(notificationsRepositoryProvider),
    'reporting' => ref.watch(reportingRepositoryProvider),
    _ => throw StateError('Unknown feature'),
  },
);
typedef CaseQuery = ({
  String collection,
  String search,
  String from,
  String to,
});
final caseRowsProvider = AsyncNotifierProvider.autoDispose
    .family<CaseRows, List<CaseRecord>, CaseQuery>(CaseRows.new);

class CaseRows extends AsyncNotifier<List<CaseRecord>> {
  final CaseQuery query;
  CaseRows(this.query);
  int page = 0;
  bool more = false, loading = false;
  Future<List<CaseRecord>> _load(int page) async {
    final result = await ref
        .read(caseGatewayProvider(query.collection.split('.').first))
        .cases(
          query.collection,
          filters: {
            'page': '$page',
            'size': '25',
            if (query.search.isNotEmpty) 'search': query.search,
            if (query.from.isNotEmpty) 'from': query.from,
            if (query.to.isNotEmpty) 'to': query.to,
          },
        );
    more = result.length == 25;
    return result;
  }

  @override
  Future<List<CaseRecord>> build() {
    page = 0;
    return _load(0);
  }

  Future<void> loadMore() async {
    if (loading || !more) return;
    loading = true;
    try {
      final next = await _load(page + 1);
      if (!ref.mounted) return;
      page++;
      final existing = state.asData?.value ?? [];
      final ids = existing.map((r) => r.id).toSet();
      state = AsyncData([...existing, ...next.where((r) => ids.add(r.id))]);
    } finally {
      loading = false;
    }
  }
}

final caseOptionsProvider = FutureProvider.autoDispose
    .family<List<CaseRecord>, String>((ref, key) async {
      final gateway = ref.watch(caseGatewayProvider(key.split('.').first));
      final result = <CaseRecord>[];
      for (var page = 0; page < 10; page++) {
        final batch = await gateway.cases(
          key,
          filters: {'page': '$page', 'size': '100'},
        );
        result.addAll(batch);
        if (batch.length < 100) return result;
      }
      throw const DataFailure(
        422,
        'LOOKUP_LIMIT',
        'This catalog is too large for a mobile selector. Ask your administrator to narrow the available choices.',
      );
    });

typedef LookupQuery = ({String collection, String search, int page});
final caseLookupPageProvider = FutureProvider.autoDispose
    .family<List<CaseRecord>, LookupQuery>(
      (ref, query) => ref
          .watch(caseGatewayProvider(query.collection.split('.').first))
          .cases(
            query.collection,
            filters: {
              'page': '${query.page}',
              'size': '25',
              if (query.search.isNotEmpty) 'search': query.search,
            },
          ),
    );
