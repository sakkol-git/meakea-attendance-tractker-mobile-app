export 'workflow_lists.dart';
import '../../../shared/presentation/case_page.dart';
import 'decision_dialog.dart';
import 'record_action_bar.dart';
import '../../../shared/domain/cases.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/shared/domain/workflow.dart';
import 'package:hrflow_mobile/shared/domain/workflow_policy.dart';
import 'package:hrflow_mobile/features/attendance/domain/correction_time.dart';
import 'package:hrflow_mobile/core/leave_quantity.dart';

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
    final detail = ref.watch(provider);
    return AppPage(
      title: 'Request details',
      bottom: detail.asData == null
          ? null
          : RecordActionBar(
              record: detail.asData!.value,
              actor: profile,
              decide: (action) => _decision(detail.asData!.value, action),
              onFulfill: () async {
                await context.push('/features/requests.fulfillment');
                ref.invalidate(provider);
              },
            ),
      onRefresh: () async {
        ref.invalidate(provider);
        await ref.read(provider.future);
      },
      children: [
        AsyncPanel(
          value: detail,
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
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _decision(WorkflowRecord r, String action) =>
      showWorkflowDecision(context, ref, r, action);
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
