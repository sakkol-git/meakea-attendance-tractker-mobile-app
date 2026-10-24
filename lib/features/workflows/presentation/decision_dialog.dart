import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/shared/domain/workflow.dart';
import 'package:hrflow_mobile/shared/domain/workflow_policy.dart';

Future<void> showWorkflowDecision(
  BuildContext context,
  WidgetRef ref,
  WorkflowRecord r,
  String action, {
  VoidCallback? onSaved,
}) async {
  String note = '';
  final form = GlobalKey<FormState>();
  String? failure;
  WriteFailureKind? outcome;
  WorkflowRecord current = r;
  WorkflowRecord? latest;
  bool busy = false;
  final actor = ref.read(sessionProvider).profile!;
  final scope =
      '${actor.tenantId}:${actor.id}:decision:${r.kind}:${r.id}:$action';
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, setDialog) {
        return Transform.translate(
          offset: Offset(0, -MediaQuery.viewInsetsOf(dialog).bottom / 2),
          child: AlertDialog(
            scrollable: true,
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.sizeOf(dialog).height -
                  MediaQuery.viewInsetsOf(dialog).bottom -
                  32,
            ),
            insetPadding: const EdgeInsets.all(16),
            title: Text(
              '${action[0].toUpperCase()}${action.substring(1)} ${r.title}?',
            ),
            content: Form(
              key: form,
              child: SingleChildScrollView(
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
                    const SizedBox(height: 8),
                    InfoRow('Employee', r.employeeName),
                    InfoRow('Request', r.title),
                    if (r.fields['startDate'] != null)
                      InfoRow(
                        'Dates',
                        '${shortDate(r.fields['startDate'])} – ${shortDate(r.fields['endDate'])}',
                      ),
                    if (r.fields['days'] != null)
                      InfoRow('Chargeable days', '${r.fields['days']}'),
                    if (r.fields['quantity'] != null)
                      InfoRow('Requested quantity', '${r.fields['quantity']}'),
                    const SizedBox(height: 16),
                    TextFormField(
                      onChanged: (value) => note = value,
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
                    if (latest != null) ...[
                      const SizedBox(height: 12),
                      InfoRow(
                        'When opened',
                        '${statusLabel(r.status)} · version ${r.version}',
                      ),
                      InfoRow(
                        'Latest',
                        '${statusLabel(latest!.status)} · version ${latest!.version}',
                      ),
                      if (!WorkflowPolicy.actions(
                        actor,
                        current,
                      ).contains(action))
                        const Text(
                          'This decision is no longer available. Return to the queue.',
                        ),
                    ],
                    if (ref
                            .read(staleResourcesProvider)
                            .asData
                            ?.value
                            .isNotEmpty ==
                        true)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Decision unavailable offline. Reconnect to verify the latest request and permissions.',
                        ),
                      ),
                    if (failure != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              outcome == WriteFailureKind.conflict
                                  ? Icons.compare_arrows
                                  : outcome == WriteFailureKind.unknown
                                  ? Icons.help_outline
                                  : Icons.error_outline,
                              color: context.semantic.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                failure!,
                                style: TextStyle(color: context.semantic.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialog),
                child: Text('Go back'),
              ),
              FilledButton(
                onPressed:
                    busy ||
                        ref
                                .read(staleResourcesProvider)
                                .asData
                                ?.value
                                .isNotEmpty ==
                            true ||
                        !WorkflowPolicy.actions(actor, current).contains(action)
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        final text = note.trim();
                        final keys = ref.read(pendingCommandKeysProvider);
                        final key = await keys.acquire(scope, {
                          'etag': current.etag,
                          'action': action,
                          'note': text,
                        });
                        setDialog(() {
                          busy = true;
                          failure = null;
                          outcome = null;
                        });
                        try {
                          await ref
                              .read(workflowUseCasesProvider(r.kind))
                              .decide(actor, current, action, text, key);
                          await keys.clear(scope);
                          ref.invalidate(
                            detailProvider((kind: r.kind, id: r.id)),
                          );
                          ref.invalidate(recordsProvider);
                          ref.invalidate(approvalProvider);
                          ref.invalidate(balancesProvider);
                          ref.invalidate(inboxProvider);
                          if (dialog.mounted) Navigator.pop(dialog);
                          if (context.mounted) {
                            if (onSaved == null) {
                              toast(context, 'Request updated');
                            } else {
                              onSaved();
                            }
                          }
                        } catch (e) {
                          final kind = writeFailureKind(e);
                          if (kind == WriteFailureKind.conflict) {
                            await keys.clear(scope);
                            try {
                              final fresh = await ref
                                  .read(workflowRepositoryProvider(r.kind))
                                  .detail(r.kind, r.id);
                              current = fresh;
                              latest = fresh;
                              ref.invalidate(
                                detailProvider((kind: r.kind, id: r.id)),
                              );
                            } catch (_) {
                              // The original conflict remains visible for a manual refresh.
                            }
                          } else if (kind == WriteFailureKind.failed) {
                            await keys.clear(scope);
                          }
                          if (dialog.mounted) {
                            setDialog(() {
                              outcome = kind;
                              failure = kind == WriteFailureKind.unknown
                                  ? 'Outcome unknown. Check the request status, then retry with the same command key.'
                                  : kind == WriteFailureKind.conflict
                                  ? 'Another reviewer changed this request. Review the latest status before deciding again.'
                                  : message(e);
                            });
                          }
                        } finally {
                          if (dialog.mounted) setDialog(() => busy = false);
                        }
                      },
                child: Text(
                  busy
                      ? 'Saving…'
                      : outcome == WriteFailureKind.unknown
                      ? 'Retry same command'
                      : latest != null
                      ? 'Decide using latest'
                      : 'Confirm',
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
