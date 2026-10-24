import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/core/leave_quantity.dart';
import 'package:hrflow_mobile/shared/domain/workflow.dart';

import 'approval_position.dart';

class WorkflowTile extends StatelessWidget {
  final WorkflowRecord record;
  final DateTime? now;
  final VoidCallback? onOpen;
  const WorkflowTile(this.record, {super.key, this.now, this.onOpen});
  @override
  Widget build(BuildContext context) {
    final r = record;
    final created = DateTime.tryParse('${r.fields['createdAt'] ?? ''}');
    final waitingDays = now == null || created == null
        ? null
        : now!.difference(created).inDays.clamp(0, 999);
    final exceptions = r.fields['policyExceptions'] as List? ?? const [];
    final dates = r.fields['startDate'] != null
        ? '${shortDate(r.fields['startDate'])} – ${shortDate(r.fields['endDate'])}'
        : r.fields['workDate'] != null
        ? shortDate(r.fields['workDate'])
        : shortDate(r.fields['createdAt']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen ?? () => context.push('/record/${r.kind}/${r.id}'),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        r.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: context.semantic.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  dates,
                  style: TextStyle(color: context.semantic.textMuted),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusPill(r.status),
                    if (waitingDays != null && r.status == 'PENDING')
                      Chip(label: Text('Waiting ${waitingDays}d')),
                    if (exceptions.isNotEmpty)
                      Tooltip(
                        message: exceptions.join(', '),
                        child: const Chip(label: Text('Policy exception')),
                      ),
                    if (r.fields['days'] != null)
                      Text(
                        formatLeaveDays(r.fields['days'] as num?),
                        style: TextStyle(fontSize: 14),
                      ),
                    if (r.fields['approvalStage'] == 'HR')
                      Text(
                        'HR review',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.semantic.warning,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WorkflowListPage extends ConsumerStatefulWidget {
  final String kind;
  const WorkflowListPage(this.kind, {super.key});
  @override
  ConsumerState<WorkflowListPage> createState() => _WorkflowListState();
}

class _WorkflowListState extends ConsumerState<WorkflowListPage> {
  String filter = 'All', search = '';
  Timer? searchDebounce;
  @override
  void dispose() {
    searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leave = widget.kind == 'leave';
    final provider = recordsProvider(
      recordQuery(
        widget.kind,
        search: search,
        status: filter == 'All' ? '' : filter.toUpperCase(),
      ),
    );
    return AppPage(
      title: leave ? 'Time off' : 'Requests',
      subtitle: leave
          ? 'A little time for what matters.'
          : 'Keep every request moving forward.',
      actions: [
        IconButton(
          tooltip: 'New ${leave ? 'leave request' : 'request'}',
          onPressed: () => context.push('/new/${widget.kind}'),
          icon: Icon(Icons.add_circle_outline),
        ),
        const SizedBox(width: 8),
      ],
      onRefresh: () async {
        ref.invalidate(provider);
        if (leave) ref.invalidate(balancesProvider);
        await ref.read(provider.future);
      },
      children: [
        if (leave) ...[
          AsyncPanel(
            value: ref.watch(balancesProvider),
            retry: () => ref.invalidate(balancesProvider),
            builder: (balances) => Column(
              children: [
                for (final b in balances)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Surface(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.semantic.successBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.spa_outlined,
                              color: context.semantic.selectedNav,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.name,
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${formatLeaveDays(b.used)} used · ${formatLeaveDays(b.pending)} pending\n${leaveBalancePeriod(b.year)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.semantic.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatLeaveDays(b.available),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SectionTitle('Your leave requests'),
        ],
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search requests',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) {
            searchDebounce?.cancel();
            searchDebounce = Timer(const Duration(milliseconds: 300), () {
              if (mounted) setState(() => search = v.trim());
            });
          },
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final v
                  in leave
                      ? ['All', 'Pending', 'Approved', 'Closed']
                      : ['All', 'Draft', 'Pending', 'Approved', 'Closed'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(v),
                    selected: filter == v,
                    onSelected: (_) => setState(() => filter = v),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AsyncPanel(
          value: ref.watch(provider),
          retry: () => ref.invalidate(provider),
          builder: (rows) {
            final controller = ref.read(provider.notifier);
            if (rows.isEmpty) {
              if (controller.canLoadMore) {
                return BusyButton(
                  label: 'Load more requests',
                  action: controller.loadMore,
                );
              }
              return EmptyState(
                title: 'Nothing here yet',
                description: search.isNotEmpty || filter != 'All'
                    ? 'Try a different search or filter.'
                    : leave
                    ? 'Your leave requests will appear here.'
                    : 'Create a request and follow its progress.',
                icon: leave
                    ? Icons.beach_access_outlined
                    : Icons.assignment_outlined,
                action: TextButton(
                  onPressed: () => context.push('/new/${widget.kind}'),
                  child: Text('Create a request'),
                ),
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${controller.total} results'),
                ),
                ...rows.map(WorkflowTile.new),
                if (controller.canLoadMore)
                  BusyButton(
                    label: 'Load more requests',
                    action: controller.loadMore,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => context.push('/new/${widget.kind}'),
          icon: Icon(Icons.add),
          label: Text(leave ? 'Request time off' : 'Create request'),
        ),
      ],
    );
  }
}

class ApprovalPage extends ConsumerStatefulWidget {
  const ApprovalPage({super.key});
  @override
  ConsumerState<ApprovalPage> createState() => _ApprovalPageState();
}

class _ApprovalPageState extends ConsumerState<ApprovalPage> {
  String search = '';
  String requestType = '', status = 'PENDING', sort = 'oldest';
  int minAgeDays = 0;
  Timer? searchDebounce;
  @override
  void dispose() {
    searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = recordsProvider(
      recordQuery(
        'approvals',
        search: search,
        status: status,
        sort: sort,
        requestType: requestType,
        minAgeDays: minAgeDays,
      ),
    );
    return AppPage(
      title: 'Team approvals',
      subtitle: 'Thoughtful decisions keep your team moving.',
      actions: [
        IconButton(
          tooltip: 'Manage delegation',
          onPressed: () => context.push('/approvals/delegations'),
          icon: const Icon(Icons.people_outline),
        ),
      ],
      onRefresh: () async {
        ref.invalidate(provider);
        await ref.read(provider.future);
      },
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search approvals',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            searchDebounce?.cancel();
            searchDebounce = Timer(const Duration(milliseconds: 300), () {
              if (mounted) setState(() => search = value.trim());
            });
          },
        ),
        ExpansionTile(
          title: const Text('Filter and sort'),
          children: [
            DropdownButtonFormField<String>(
              initialValue: requestType,
              decoration: const InputDecoration(labelText: 'Request type'),
              items: const [
                DropdownMenuItem(value: '', child: Text('All types')),
                DropdownMenuItem(value: 'leave', child: Text('Leave')),
                DropdownMenuItem(value: 'request', child: Text('Requests')),
                DropdownMenuItem(
                  value: 'correction',
                  child: Text('Corrections'),
                ),
              ],
              onChanged: (value) => setState(() => requestType = value ?? ''),
            ),
            DropdownButtonFormField<int>(
              initialValue: minAgeDays,
              decoration: const InputDecoration(labelText: 'Waiting age'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Any age')),
                DropdownMenuItem(value: 1, child: Text('At least 1 day')),
                DropdownMenuItem(value: 3, child: Text('At least 3 days')),
                DropdownMenuItem(value: 7, child: Text('At least 7 days')),
              ],
              onChanged: (value) => setState(() => minAgeDays = value ?? 0),
            ),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
                DropdownMenuItem(value: 'APPROVED', child: Text('Approved')),
                DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
              ],
              onChanged: (value) => setState(() => status = value ?? 'PENDING'),
            ),
            DropdownButtonFormField<String>(
              initialValue: sort,
              decoration: const InputDecoration(labelText: 'Sort'),
              items: const [
                DropdownMenuItem(value: 'oldest', child: Text('Oldest first')),
                DropdownMenuItem(value: 'newest', child: Text('Newest first')),
              ],
              onChanged: (value) => setState(() => sort = value ?? 'oldest'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AsyncPanel(
          value: ref.watch(provider),
          retry: () => ref.invalidate(provider),
          builder: (rows) => rows.isEmpty
              ? ref.read(provider.notifier).canLoadMore
                    ? const SizedBox.shrink()
                    : const EmptyState(
                        title: 'You’re all caught up',
                        description: 'New team requests will appear here.',
                        icon: Icons.task_alt,
                      )
              : Column(
                  children: [
                    Text(
                      '${ref.read(provider.notifier).total} '
                      '${ref.read(provider.notifier).total == 1 ? 'result' : 'results'}',
                    ),
                    for (final (index, row) in rows.indexed)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 6),
                            child: Text(
                              row.employeeName,
                              style: TextStyle(
                                color: context.semantic.textMuted,
                              ),
                            ),
                          ),
                          WorkflowTile(
                            row,
                            now: ref.read(clockProvider)(),
                            onOpen: () => context.push(
                              '/record/${row.kind}/${row.id}',
                              extra: ApprovalPosition(rows, index),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
        if (ref.read(provider.notifier).canLoadMore)
          BusyButton(
            label: 'Load more approvals',
            action: () => ref.read(provider.notifier).loadMore(),
          ),
      ],
    );
  }
}
