import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/widgets.dart';

import '../application/providers.dart';
import '../domain/delegation.dart';
import 'delegate_picker.dart';

class DelegationsPage extends ConsumerWidget {
  const DelegationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: 'Approval delegation',
    subtitle: 'Assign a qualified reviewer for a defined period. You remain accountable.',
    actions: [
      IconButton(
        tooltip: 'New delegation',
        icon: const Icon(Icons.add),
        onPressed: () async {
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (_) => const _DelegationForm(),
          );
          ref.invalidate(delegationsProvider);
        },
      ),
    ],
    onRefresh: () async {
      ref.invalidate(delegationsProvider);
      await ref.read(delegationsProvider.future);
    },
    children: [
      AsyncPanel(
        value: ref.watch(delegationsProvider),
        retry: () => ref.invalidate(delegationsProvider),
        builder: (rows) => rows.isEmpty
            ? const EmptyState(
                title: 'No delegations',
                description: 'Create a delegation when another reviewer must cover your approvals.',
                icon: Icons.fact_check_outlined,
              )
            : Column(
                children: [
                  for (final row in rows)
                    Card(
                      child: ListTile(
                        title: Text(row.delegateName),
                        subtitle: Text(
                          '${row.startsOn} – ${row.endsOn} · ${row.status}',
                        ),
                        trailing: row.status == 'ACTIVE'
                            ? IconButton(
                                tooltip: 'Cancel delegation',
                                icon: const Icon(Icons.close),
                                onPressed: () => _cancel(context, ref, row),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
      ),
    ],
  );

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    ApprovalDelegation row,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Cancel delegation?'),
        content: Text(
          '${row.delegateName} will stop receiving delegated approvals.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Cancel delegation'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(delegationRepositoryProvider).cancel(row);
      ref.invalidate(delegationsProvider);
      if (context.mounted) toast(context, 'Delegation cancelled');
    } catch (error) {
      if (context.mounted) toast(context, message(error));
    }
  }
}

class _DelegationForm extends ConsumerStatefulWidget {
  const _DelegationForm();
  @override
  ConsumerState<_DelegationForm> createState() => _DelegationFormState();
}

class _DelegationFormState extends ConsumerState<_DelegationForm> {
  final reason = TextEditingController();
  EligibleDelegate? delegate;
  DateTime? start, end;
  bool busy = false, dirty = false;
  String? error;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> chooseDate(bool first) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: first
          ? (start ?? DateTime.now())
          : (end ?? start ?? DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        dirty = true;
        if (first) {
          start = picked;
          if (end != null && end!.isBefore(picked)) end = null;
        } else {
          end = picked;
        }
      });
    }
  }

  Future<void> save() async {
    if (delegate == null ||
        start == null ||
        end == null ||
        end!.isBefore(start!) ||
        reason.text.trim().length < 5) {
      setState(
        () => error = 'Choose a reviewer, valid dates and a reason of at least 5 characters.',
      );
      return;
    }
    final profile = ref.read(sessionProvider).profile!;
    final body = {
      'delegateId': delegate!.id,
      'startsOn': start!.toIso8601String().substring(0, 10),
      'endsOn': end!.toIso8601String().substring(0, 10),
      'reason': reason.text.trim(),
    };
    final keys = ref.read(pendingCommandKeysProvider);
    final scope = '${profile.tenantId}:${profile.id}:delegation:create';
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final key = await keys.acquire(scope, body);
      await ref
          .read(delegationRepositoryProvider)
          .create(
            delegate!.id,
            body['startsOn']!,
            body['endsOn']!,
            body['reason']!,
            key,
          );
      await keys.clear(scope);
      if (mounted) {
        setState(() {
          busy = false;
          dirty = false;
        });
        Navigator.pop(context);
      }
    } catch (failure) {
      if (mounted) setState(() => error = message(failure));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy && !dirty,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop || busy || !dirty) return;
      if (await _confirmDiscard() && mounted) {
        setState(() => dirty = false);
        Navigator.pop(this.context);
      }
    },
    child: AlertDialog(
      title: const Text('New approval delegation'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.person_search),
              onPressed: busy
                  ? null
                  : () async {
                      final selected = await pickDelegate(context);
                      if (selected != null && mounted) {
                        setState(() {
                          delegate = selected;
                          dirty = true;
                        });
                      }
                    },
              label: Text(delegate?.name ?? 'Choose reviewer · Required'),
            ),
            TextButton(
              onPressed: busy ? null : () => chooseDate(true),
              child: Text(
                start == null
                    ? 'Start date · Required'
                    : 'Start: ${start!.toIso8601String().substring(0, 10)}',
              ),
            ),
            TextButton(
              onPressed: busy ? null : () => chooseDate(false),
              child: Text(
                end == null
                    ? 'End date · Required'
                    : 'End: ${end!.toIso8601String().substring(0, 10)}',
              ),
            ),
            TextField(
              controller: reason,
              maxLines: 2,
              onChanged: (_) => setState(() => dirty = true),
              decoration: const InputDecoration(labelText: 'Reason · Required'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error!),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : _close,
          child: const Text('Go back'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? 'Saving…' : 'Create delegation'),
        ),
      ],
    ),
  );

  Future<bool> _confirmDiscard() async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Discard delegation?'),
          content: const Text('Your unsaved changes will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _close() async {
    if (dirty && !await _confirmDiscard()) return;
    if (mounted) {
      setState(() => dirty = false);
      Navigator.pop(context);
    }
  }
}
