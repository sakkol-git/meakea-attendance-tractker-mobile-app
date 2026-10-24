import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrflow_mobile/shared/domain/workflow.dart';
import 'package:hrflow_mobile/app/providers.dart';

import '../domain/repository.dart';
import 'use_cases.dart';

final workflowRepositoryProvider = Provider.family<WorkflowRepository, String>(
  (ref, kind) => switch (kind) {
    'leave' => ref.watch(leaveRepositoryProvider),
    'correction' => ref.watch(attendanceRepositoryProvider),
    _ => ref.watch(requestsRepositoryProvider),
  },
);
final recordsProvider = AsyncNotifierProvider.autoDispose
    .family<RecordListController, List<WorkflowRecord>, String>(
      RecordListController.new,
    );

class RecordListController extends AsyncNotifier<List<WorkflowRecord>> {
  final String kind;
  RecordListController(this.kind);
  int _page = 0;
  bool canLoadMore = false;
  bool _loadingMore = false;
  Future<List<WorkflowRecord>> _read(int page) async {
    final repository = ref.read(workflowRepositoryProvider(kind));
    final pages = await Future.wait(
      kind == 'approvals'
          ? ['leave', 'request', 'correction'].map(
              (type) => ref
                  .read(workflowRepositoryProvider(type))
                  .recordsPage(type, pending: true, page: page),
            )
          : [repository.recordsPage(kind, page: page)],
    );
    canLoadMore = pages.any((p) => p.hasMore);
    return pages.expand((p) => p.records).toList();
  }

  @override
  Future<List<WorkflowRecord>> build() async {
    _page = 0;
    return _read(0);
  }

  Future<void> loadMore() async {
    if (_loadingMore || !canLoadMore) return;
    _loadingMore = true;
    try {
      final rows = await _read(_page + 1);
      if (!ref.mounted) return;
      _page++;
      final existing = state.asData?.value ?? [];
      final keys = existing.map((r) => '${r.kind}:${r.id}').toSet();
      state = AsyncData([
        ...existing,
        ...rows.where((r) => keys.add('${r.kind}:${r.id}')),
      ]);
    } finally {
      _loadingMore = false;
    }
  }
}

final detailProvider = FutureProvider.autoDispose
    .family<WorkflowRecord, ({String kind, String id})>(
      (ref, key) => ref
          .watch(workflowRepositoryProvider(key.kind))
          .detail(key.kind, key.id),
    );
final approvalProvider = recordsProvider('approvals');
final workflowUseCasesProvider = Provider.family<WorkflowUseCases, String>(
  (ref, kind) => WorkflowUseCases(ref.watch(workflowRepositoryProvider(kind))),
);
