import '../../../shared/presentation/case_page.dart';
import '../../../shared/domain/cases.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/shared/domain/workflow.dart';
import 'package:hrflow_mobile/shared/domain/workflow_policy.dart';
import 'package:hrflow_mobile/features/attendance/domain/correction_time.dart';
import 'package:hrflow_mobile/core/leave_quantity.dart';

class WorkflowTile extends StatelessWidget {
  final WorkflowRecord record;
  const WorkflowTile(this.record, {super.key});
  @override
  Widget build(BuildContext context) {
    final r = record;
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
          onTap: () => context.push('/record/${r.kind}/${r.id}'),
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
  Timer? searchDebounce;
  @override
  void dispose() {
    searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = recordsProvider(
      recordQuery('approvals', search: search, sort: 'oldest'),
    );
    return AppPage(
      title: 'Team approvals',
      subtitle: 'Thoughtful decisions keep your team moving.',
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
                    Text('${ref.read(provider.notifier).total} results'),
                    for (final row in rows)
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
                          WorkflowTile(row),
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

class RecordDetailPage extends ConsumerStatefulWidget {
  final String kind, id;
  const RecordDetailPage(this.kind, this.id, {super.key});
  @override
  ConsumerState<RecordDetailPage> createState() => _RecordDetailState();
}

class _RecordDetailState extends ConsumerState<RecordDetailPage> {
  bool working = false;
  String? error;
  String? attachmentName;
  @override
  Widget build(BuildContext context) {
    final provider = detailProvider((kind: widget.kind, id: widget.id));
    final profile = ref.watch(sessionProvider).profile!;
    return AppPage(
      title: 'Request details',
      onRefresh: () async {
        ref.invalidate(provider);
        await ref.read(provider.future);
      },
      children: [
        AsyncPanel(
          value: ref.watch(provider),
          retry: () => ref.invalidate(provider),
          builder: (r) {
            final actions = WorkflowPolicy.actions(profile, r);
            final decisions = (r.fields['decisions'] as List? ?? [])
                .map((v) => Map<String, dynamic>.from(v as Map))
                .toList();
            final files = (r.fields['attachments'] as List? ?? [])
                .map((v) => Map<String, dynamic>.from(v as Map))
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusPill(r.status),
                      const SizedBox(height: 18),
                      Text(
                        r.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Requested by ${r.employeeName}',
                        style: TextStyle(color: context.semantic.textMuted),
                      ),
                      const Divider(height: 32),
                      if (r.fields['startDate'] != null) ...[
                        InfoRow('From', shortDate(r.fields['startDate'])),
                        InfoRow('To', shortDate(r.fields['endDate'])),
                      ],
                      if (r.fields['days'] != null)
                        InfoRow(
                          'Duration',
                          formatLeaveDays(r.fields['days'] as num?),
                        ),
                      if (r.fields['halfDay'] != null &&
                          r.fields['halfDay'] != 'NONE')
                        InfoRow('Day portion', r.fields['halfDay'].toString()),
                      if (r.fields['workDate'] != null)
                        InfoRow(
                          'Affected date',
                          shortDate(r.fields['workDate']),
                        ),
                      if (r.kind == 'correction') ...[
                        const SizedBox(height: 12),
                        Text(
                          'Original recorded time',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if ((r.fields['previousSessions'] as List? ?? [])
                            .isEmpty)
                          const InfoRow('Original', 'No recorded session'),
                        for (final raw
                            in r.fields['previousSessions'] as List? ?? [])
                          Builder(
                            builder: (context) {
                              final session = Map<String, dynamic>.from(
                                raw as Map,
                              );
                              return InfoRow(
                                'Original',
                                '${CorrectionTime.display(DateTime.tryParse((session['checkInAt'] ?? session['clockIn'] ?? '').toString()))} → ${CorrectionTime.display(DateTime.tryParse((session['checkOutAt'] ?? session['clockOut'] ?? '').toString()))}',
                              );
                            },
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Proposed correction',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const InfoRow('Time zone', 'Asia/Phnom_Penh (UTC+07)'),
                      ],
                      if (r.fields['newCheckIn'] != null)
                        InfoRow(
                          'Requested clock in',
                          CorrectionTime.display(
                            DateTime.tryParse(r.fields['newCheckIn']),
                          ),
                        ),
                      if (r.fields['newCheckOut'] != null)
                        InfoRow(
                          'Requested clock out',
                          CorrectionTime.display(
                            DateTime.tryParse(r.fields['newCheckOut']),
                          ),
                        ),
                      if (r.fields['type'] != null)
                        InfoRow(
                          'Type',
                          r.fields['type'].toString().replaceAll('_', ' '),
                        ),
                      if (r.fields['quantity'] != null)
                        InfoRow('Quantity', r.fields['quantity'].toString()),
                      for (final item in r.fields['items'] as List? ?? [])
                        InfoRow(
                          ref
                                  .watch(collectionProvider('/materials'))
                                  .asData
                                  ?.value
                                  .where((m) => m['id'] == item['materialId'])
                                  .firstOrNull?['name']
                                  ?.toString() ??
                              'Material',
                          '${item['quantity']} requested · ${(r.fields['issuedQuantities'] as Map?)?[item['materialId']] ?? 0} issued',
                        ),
                      if (r.fields['fromTime'] != null)
                        InfoRow('From time', r.fields['fromTime'].toString()),
                      if (r.fields['toTime'] != null)
                        InfoRow('Until time', r.fields['toTime'].toString()),
                      if (r.fields['currentApproverName'] != null &&
                          r.status == 'PENDING')
                        InfoRow(
                          'Next reviewer',
                          r.fields['currentApproverName'].toString(),
                        ),
                      if (r.fields['approvalStage'] == 'HR')
                        const InfoRow('Next step', 'HR approval'),
                      const SizedBox(height: 12),
                      Text(
                        'Reason',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        r.reason.isEmpty
                            ? 'No additional details provided.'
                            : r.reason,
                      ),
                    ],
                  ),
                ),
                if (r.kind == 'request') ...[
                  const SectionTitle('Discussion'),
                  for (final comment in r.fields['comments'] as List? ?? [])
                    Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment['actor']?.toString() ?? 'Reviewer',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(comment['text']?.toString() ?? ''),
                          Text(shortDate(comment['at'])),
                        ],
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await showCaseEditor(
                        context,
                        ref,
                        const CaseAction(
                          'requests.comment',
                          'Add comment',
                          fields: [
                            CaseField('text', 'Comment', kind: FieldKind.note),
                          ],
                        ),
                        CaseRecord(
                          id: r.id,
                          title: r.title,
                          status: r.status,
                          version: r.version,
                          values: r.fields,
                        ),
                      );
                      ref.invalidate(provider);
                    },
                    icon: Icon(Icons.chat_bubble_outline),
                    label: Text('Add comment'),
                  ),
                ],
                if (r.kind == 'request' || r.kind == 'leave') ...[
                  const SectionTitle('Attachments'),
                  Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (files.isEmpty)
                          Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text(
                              'No attachments yet.',
                              style: TextStyle(
                                color: context.semantic.textMuted,
                              ),
                            ),
                          ),
                        for (final file in files)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.attach_file),
                            title: Text(
                              file['name'] as String? ?? 'Attachment',
                            ),
                            subtitle: Text(
                              '${((file['size'] as num? ?? 0) / 1024).ceil()} KB',
                            ),
                            trailing: IconButton(
                              tooltip: 'Download and share attachment',
                              onPressed: working
                                  ? null
                                  : () async {
                                      setState(() => working = true);
                                      try {
                                        final bytes = await ref
                                            .read(
                                              workflowRepositoryProvider(
                                                widget.kind,
                                              ),
                                            )
                                            .download(r, file);
                                        if (context.mounted) {
                                          final box =
                                              context.findRenderObject()
                                                  as RenderBox?;
                                          await SharePlus.instance.share(
                                            ShareParams(
                                              files: [
                                                XFile.fromData(
                                                  bytes,
                                                  mimeType: 'application/octet-stream',
                                                ),
                                              ],
                                              fileNameOverrides: [
                                                file['name'] as String? ??
                                                    'attachment',
                                              ],
                                              sharePositionOrigin: box == null
                                                  ? null
                                                  : box.localToGlobal(
                                                          Offset.zero,
                                                        ) &
                                                        box.size,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          toast(context, message(e));
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() => working = false);
                                        }
                                      }
                                    },
                              icon: Icon(Icons.download_outlined),
                            ),
                          ),
                        if (actions.contains('cancel'))
                          OutlinedButton.icon(
                            onPressed: working
                                ? null
                                : () async {
                                    final picked = await FilePicker.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: [
                                        'pdf',
                                        'png',
                                        'jpg',
                                        'jpeg',
                                      ],
                                    );
                                    if (picked.isEmpty) return;
                                    setState(() => working = true);
                                    try {
                                      final length = await picked.first
                                          .length();
                                      if (length == null ||
                                          length > 10 * 1024 * 1024) {
                                        if (context.mounted) {
                                          toast(
                                            context,
                                            'Choose a file smaller than 10 MB.',
                                          );
                                        }
                                        return;
                                      }
                                      final bytes = await picked.first
                                          .readAsBytes();
                                      await ref
                                          .read(
                                            workflowRepositoryProvider(
                                              widget.kind,
                                            ),
                                          )
                                          .attach(r, picked.first.name, bytes);
                                      ref.invalidate(provider);
                                      if (context.mounted) {
                                        toast(context, 'Attachment added');
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        toast(context, message(e));
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => working = false);
                                      }
                                    }
                                  },
                            icon: Icon(Icons.add),
                            label: Text(
                              working
                                  ? 'Working…'
                                  : 'Add attachment · up to 10 MB',
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SectionTitle('Activity'),
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TimelineItem(
                        title: 'Request created',
                        subtitle: companyTimestamp(
                          r.fields['createdAt']?.toString(),
                        ),
                        icon: Icons.add_circle_outline,
                      ),
                      for (final decision in decisions)
                        _TimelineItem(
                          title:
                              '${decision['actor'] ?? 'Reviewer'} · ${statusLabel(decision['action'] as String? ?? '')}',
                          subtitle:
                              '${decision['note'] ?? ''}${decision['note']?.toString().isNotEmpty == true ? '\n' : ''}${companyTimestamp(decision['at']?.toString())}',
                          icon: Icons.check_circle_outline,
                        ),
                      if (r.status == 'PENDING')
                        _TimelineItem(
                          title: r.fields['approvalStage'] == 'HR'
                              ? 'Waiting for HR review'
                              : 'Waiting for review',
                          subtitle:
                              'You’ll be notified when a decision is made.',
                          icon: Icons.hourglass_empty,
                        ),
                    ],
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      error!,
                      style: TextStyle(color: context.semantic.error),
                    ),
                  ),
                const SizedBox(height: 24),
                if (actions.contains('submit'))
                  OutlinedButton.icon(
                    onPressed: () => context.push('/edit/request/${r.id}'),
                    icon: Icon(Icons.edit_outlined),
                    label: Text('Edit draft'),
                  ),
                const SizedBox(height: 8),
                if (actions.contains('submit'))
                  BusyButton(
                    label: 'Submit request',
                    icon: Icons.send_outlined,
                    action: () => _decision(r, 'submit'),
                  ),
                if (actions.contains('cancel'))
                  TextButton(
                    onPressed: () => _decision(r, 'cancel'),
                    child: Text('Cancel request'),
                  ),
                if (actions.contains('approve')) ...[
                  BusyButton(
                    label: 'Approve request',
                    icon: Icons.check,
                    action: () => _decision(r, 'approve'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _decision(r, 'reject'),
                    icon: Icon(Icons.close),
                    label: Text('Reject request'),
                  ),
                ],
                if (actions.contains('fulfill'))
                  BusyButton(
                    label: 'Issue approved materials',
                    icon: Icons.inventory_2_outlined,
                    action: () async {
                      await context.push('/features/requests.fulfillment');
                      ref.invalidate(provider);
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _decision(WorkflowRecord r, String action) async {
    final note = TextEditingController();
    final form = GlobalKey<FormState>();
    String? failure;
    bool busy = false;
    var key = commandKey();
    String last = '';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setDialog) => AlertDialog(
          title: Text(
            '${action[0].toUpperCase()}${action.substring(1)} request?',
          ),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action == 'reject'
                      ? 'A clear reason helps the employee understand your decision.'
                      : action == 'cancel'
                      ? 'The request will be cancelled. This decision is recorded.'
                      : 'Review the details before confirming your decision.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: note,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: action == 'reject'
                        ? 'Reason'
                        : 'Note (optional)',
                  ),
                  validator: (v) =>
                      action == 'reject' && (v?.trim().length ?? 0) < 5
                      ? 'Give a reason with at least 5 characters'
                      : null,
                ),
                if (failure != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      failure!,
                      style: TextStyle(color: context.semantic.error),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialog),
              child: Text('Go back'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      final text = note.text.trim();
                      if (text != last) {
                        key = commandKey();
                        last = text;
                      }
                      setDialog(() {
                        busy = true;
                        failure = null;
                      });
                      try {
                        await ref
                            .read(workflowUseCasesProvider(widget.kind))
                            .decide(
                              ref.read(sessionProvider).profile!,
                              r,
                              action,
                              text,
                              key,
                            );
                        ref.invalidate(
                          detailProvider((kind: widget.kind, id: widget.id)),
                        );
                        ref.invalidate(recordsProvider);
                        ref.invalidate(approvalProvider);
                        ref.invalidate(balancesProvider);
                        ref.invalidate(inboxProvider);
                        if (dialog.mounted) Navigator.pop(dialog);
                        if (mounted) toast(context, 'Request updated');
                      } catch (e) {
                        if (dialog.mounted) {
                          setDialog(() => failure = message(e));
                        }
                      } finally {
                        if (dialog.mounted) setDialog(() => busy = false);
                      }
                    },
              child: Text(busy ? 'Saving…' : 'Confirm'),
            ),
          ],
        ),
      ),
    );
    note.dispose();
  }
}

class _TimelineItem extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  const _TimelineItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: c.semantic.selectedNav),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: c.semantic.textMuted),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
