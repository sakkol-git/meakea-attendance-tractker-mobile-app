import 'package:hrflow_mobile/shared/domain/workflow.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/core/protocol.dart';

class RequestFormPage extends ConsumerStatefulWidget {
  final String kind;
  final WorkflowRecord? initial;
  const RequestFormPage(this.kind, {super.key, this.initial});
  @override
  ConsumerState<RequestFormPage> createState() => _RequestFormState();
}

class _RequestFormState extends ConsumerState<RequestFormPage> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      reason = TextEditingController(),
      quantity = TextEditingController(text: '1');
  String? type, material;
  final additionalMaterials = <JsonMap>[];
  String halfDay = 'NONE', requestType = 'GENERAL';
  late DateTime from, to;
  TimeOfDay start = const TimeOfDay(hour: 8, minute: 30),
      end = const TimeOfDay(hour: 17, minute: 30);
  String? key, lastPayload;
  bool dirty = false, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    from = to = DateTime(now.year, now.month, now.day);
    final initial = widget.initial;
    if (initial != null) {
      title.text = initial.title;
      reason.text = initial.reason;
      requestType = initial.fields['type'] as String? ?? 'GENERAL';
      from =
          DateTime.tryParse(initial.fields['startDate'] as String? ?? '') ??
          from;
      to =
          DateTime.tryParse(initial.fields['endDate'] as String? ?? '') ?? from;
      final items = initial.fields['items'] as List? ?? [];
      if (items.isNotEmpty) {
        material = items.first['materialId'];
        quantity.text = '${items.first['quantity']}';
        additionalMaterials.addAll(
          items.skip(1).map((v) => JsonMap.from(v as Map)),
        );
      }
      TimeOfDay parseTime(String? value, TimeOfDay fallback) {
        final parts = (value ?? '').split(':');
        return parts.length == 2 &&
                int.tryParse(parts[0]) != null &&
                int.tryParse(parts[1]) != null
            ? TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]))
            : fallback;
      }

      start = parseTime(initial.fields['fromTime'] as String?, start);
      end = parseTime(initial.fields['toTime'] as String?, end);
    }
  }

  @override
  void dispose() {
    title.dispose();
    reason.dispose();
    quantity.dispose();
    super.dispose();
  }

  Future<void> date(bool first) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: first ? from : to,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() {
        dirty = true;
        if (first) {
          from = picked;
          if (to.isBefore(from)) to = from;
        } else {
          to = picked;
        }
      });
    }
  }

  Future<void> time(bool first) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: first ? start : end,
    );
    if (picked != null) {
      setState(() {
        dirty = true;
        if (first) {
          start = picked;
        } else {
          end = picked;
        }
      });
    }
  }

  String iso(DateTime d) => d.toIso8601String().substring(0, 10);
  Future<bool> discard() async {
    if (!dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Discard this draft?'),
            content: const Text('Your unsaved changes will be lost.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final leave = widget.kind == 'leave',
        correction = widget.kind == 'correction';
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await discard() && context.mounted) {
          setState(() => dirty = false);
          context.pop();
        }
      },
      child: AppPage(
        canLeave: discard,
        title: leave
            ? 'Request time off'
            : correction
            ? 'Fix attendance'
            : 'New request',
        subtitle: leave
            ? 'Plan a break. We’ll take care of the paperwork.'
            : correction
            ? 'Help your manager understand what needs correcting.'
            : 'A clear request is easier to approve.',
        children: [
          Form(
            key: form,
            onChanged: () => dirty = true,
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (leave)
                    AsyncPanel(
                      value: ref.watch(collectionProvider('/leave/types')),
                      retry: () =>
                          ref.invalidate(collectionProvider('/leave/types')),
                      builder: (types) => DropdownButtonFormField<String>(
                        isExpanded: true,
                        itemHeight: null,
                        initialValue: type,
                        decoration: const InputDecoration(
                          labelText: 'Leave type',
                        ),
                        items: [
                          for (final t in types)
                            DropdownMenuItem(
                              value: t['id'] as String,
                              child: Text(t['name'] as String),
                            ),
                        ],
                        onChanged: saving
                            ? null
                            : (v) => setState(() => type = v),
                        validator: (v) =>
                            v == null ? 'Choose a leave type' : null,
                      ),
                    ),
                  if (!leave && !correction) ...[
                    TextFormField(
                      controller: title,
                      decoration: const InputDecoration(
                        labelText: 'Request title',
                        hintText: 'What do you need?',
                      ),
                      maxLength: 100,
                      validator: (v) => (v?.trim().length ?? 0) < 3
                          ? 'Enter at least 3 characters'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    AsyncPanel(
                      value: ref.watch(collectionProvider('/requests/types')),
                      retry: () =>
                          ref.invalidate(collectionProvider('/requests/types')),
                      builder: (types) => DropdownButtonFormField<String>(
                        isExpanded: true,
                        itemHeight: null,
                        initialValue: types.any((t) => t['code'] == requestType)
                            ? requestType
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Request type',
                        ),
                        items: [
                          for (final t in types.where(
                            (t) => t['active'] != false,
                          ))
                            DropdownMenuItem(
                              value: t['code'] as String,
                              child: Text(t['name'] as String),
                            ),
                        ],
                        validator: (v) => v == null
                            ? 'Choose an available request type'
                            : null,
                        onChanged: saving
                            ? null
                            : (v) => setState(() => requestType = v!),
                      ),
                    ),
                    if (requestType == 'MATERIAL') ...[
                      const SizedBox(height: 16),
                      AsyncPanel(
                        value: ref.watch(collectionProvider('/materials')),
                        retry: () =>
                            ref.invalidate(collectionProvider('/materials')),
                        builder: (values) => DropdownButtonFormField<String>(
                          key: ValueKey(
                            'material-${additionalMaterials.length}-$material',
                          ),
                          isExpanded: true,
                          itemHeight: null,
                          initialValue: material,
                          decoration: const InputDecoration(
                            labelText: 'Material',
                          ),
                          items: [
                            for (final v in values.where(
                              (v) =>
                                  v['status'] != 'ARCHIVED' &&
                                  !additionalMaterials.any(
                                    (m) => m['materialId'] == v['id'],
                                  ),
                            ))
                              DropdownMenuItem(
                                value: v['id'] as String,
                                child: Text(v['name'] as String),
                              ),
                          ],
                          onChanged: (v) => setState(() => material = v),
                          validator: (v) =>
                              v == null && additionalMaterials.isEmpty
                              ? 'Choose a material'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: quantity,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (material == null &&
                              additionalMaterials.isNotEmpty) {
                            return null;
                          }
                          final n = int.tryParse(v ?? '');
                          return n == null || n < 1 || n > 100
                              ? 'Enter a quantity from 1 to 100'
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      for (final item in additionalMaterials)
                        Card(
                          child: ListTile(
                            title: Text(
                              ref
                                      .watch(collectionProvider('/materials'))
                                      .asData
                                      ?.value
                                      .where(
                                        (m) => m['id'] == item['materialId'],
                                      )
                                      .firstOrNull?['name']
                                      ?.toString() ??
                                  'Material',
                            ),
                            subtitle: Text('Quantity: ${item['quantity']}'),
                            trailing: IconButton(
                              tooltip: 'Remove material',
                              onPressed: saving
                                  ? null
                                  : () => setState(
                                      () => additionalMaterials.remove(item),
                                    ),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        ),
                      TextButton.icon(
                        onPressed: saving || material == null
                            ? null
                            : () {
                                final qty = int.tryParse(quantity.text);
                                if (qty == null || qty < 1 || qty > 100) {
                                  setState(
                                    () => error =
                                        'Enter a quantity from 1 to 100.',
                                  );
                                  return;
                                }
                                setState(() {
                                  additionalMaterials.add({
                                    'materialId': material,
                                    'quantity': qty,
                                  });
                                  material = null;
                                  quantity.text = '1';
                                  dirty = true;
                                  error = null;
                                });
                              },
                        icon: const Icon(Icons.add),
                        label: const Text('Add another material'),
                      ),
                    ],
                  ],
                  if (leave ||
                      correction ||
                      requestType != 'GENERAL' &&
                          requestType != 'MATERIAL') ...[
                    const SizedBox(height: 20),
                    _FieldButton(
                      label: correction ? 'Affected date' : 'From',
                      value: shortDate(iso(from)),
                      icon: Icons.calendar_today_outlined,
                      onTap: saving ? null : () => date(true),
                    ),
                    if (leave || requestType == 'REMOTE_WORK') ...[
                      const SizedBox(height: 12),
                      _FieldButton(
                        label: 'To',
                        value: shortDate(iso(to)),
                        icon: Icons.calendar_today_outlined,
                        onTap: saving ? null : () => date(false),
                      ),
                    ],
                    if (leave) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        itemHeight: null,
                        initialValue: halfDay,
                        decoration: const InputDecoration(
                          labelText: 'Day portion',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'NONE',
                            child: Text('Full day'),
                          ),
                          DropdownMenuItem(
                            value: 'AM',
                            child: Text('Morning only'),
                          ),
                          DropdownMenuItem(
                            value: 'PM',
                            child: Text('Afternoon only'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (v) => setState(() => halfDay = v!),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Weekends and company holidays are excluded in the demo. Your company’s policy determines the final balance.',
                        style: TextStyle(fontSize: 12, color: Palette.muted),
                      ),
                    ],
                    if (correction ||
                        requestType == 'LATE_ARRIVAL' ||
                        requestType == 'EARLY_LEAVE') ...[
                      const SizedBox(height: 16),
                      _FieldButton(
                        label: correction
                            ? 'Correct clock-in time'
                            : 'From time',
                        value: start.format(context),
                        icon: Icons.schedule_outlined,
                        onTap: saving ? null : () => time(true),
                      ),
                      const SizedBox(height: 12),
                      _FieldButton(
                        label: correction
                            ? 'Correct clock-out time'
                            : 'To time',
                        value: end.format(context),
                        icon: Icons.schedule_outlined,
                        onTap: saving ? null : () => time(false),
                      ),
                    ],
                  ],
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: reason,
                    decoration: InputDecoration(
                      labelText: correction ? 'What happened?' : 'Reason',
                      hintText: 'Add enough detail for your reviewer.',
                    ),
                    maxLines: 5,
                    maxLength: 1000,
                    validator: (v) => (v?.trim().length ?? 0) < 5
                        ? 'Give a reason with at least 5 characters'
                        : null,
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Palette.danger),
                      ),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: saving ? null : submit,
                    icon: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(
                      saving
                          ? 'Saving…'
                          : !leave && !correction
                          ? 'Save request draft'
                          : 'Send for approval',
                    ),
                  ),
                  if (!leave && !correction)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'You can add attachments and review the draft before submitting.',
                        style: TextStyle(fontSize: 12, color: Palette.muted),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final leave = widget.kind == 'leave',
        correction = widget.kind == 'correction';
    if (to.isBefore(from)) {
      setState(() => error = 'The end date must follow the start date.');
      return;
    }
    if (leave && halfDay != 'NONE' && from != to) {
      setState(() => error = 'Half-day requests must be on a single date.');
      return;
    }
    if ((correction ||
            requestType == 'LATE_ARRIVAL' ||
            requestType == 'EARLY_LEAVE') &&
        (end.hour * 60 + end.minute <= start.hour * 60 + start.minute)) {
      setState(() => error = 'The end time must follow the start time.');
      return;
    }
    String stamp(TimeOfDay t) => DateTime.utc(
      from.year,
      from.month,
      from.day,
      t.hour,
      t.minute,
    ).subtract(const Duration(hours: 7)).toIso8601String();
    final body = <String, dynamic>{
      'reason': reason.text.trim(),
      if (leave) ...{
        'leaveTypeId': type,
        'startDate': iso(from),
        'endDate': iso(to),
        'halfDay': halfDay,
      },
      if (correction) ...{
        'workDate': iso(from),
        'newCheckIn': stamp(start),
        'newCheckOut': stamp(end),
      },
      if (!leave && !correction) ...{
        'title': title.text.trim(),
        'description': reason.text.trim(),
        'type': requestType,
        if (![
          'REMOTE_WORK',
          'LATE_ARRIVAL',
          'EARLY_LEAVE',
        ].contains(requestType))
          'startDate': null,
        if (![
          'REMOTE_WORK',
          'LATE_ARRIVAL',
          'EARLY_LEAVE',
        ].contains(requestType))
          'endDate': null,
        if (!['LATE_ARRIVAL', 'EARLY_LEAVE'].contains(requestType))
          'fromTime': null,
        if (!['LATE_ARRIVAL', 'EARLY_LEAVE'].contains(requestType))
          'toTime': null,
        'items': requestType == 'MATERIAL'
            ? [
                ...additionalMaterials,
                if (material != null)
                  {
                    'materialId': material,
                    'quantity': int.parse(quantity.text),
                  },
              ]
            : [],
        'quantity': requestType == 'MATERIAL'
            ? additionalMaterials.fold<int>(
                    0,
                    (sum, item) => sum + (item['quantity'] as int),
                  ) +
                  (material == null ? 0 : int.parse(quantity.text))
            : null,
        if (requestType == 'REMOTE_WORK' ||
            requestType == 'LATE_ARRIVAL' ||
            requestType == 'EARLY_LEAVE')
          'startDate': iso(from),
        if (requestType == 'REMOTE_WORK' ||
            requestType == 'LATE_ARRIVAL' ||
            requestType == 'EARLY_LEAVE')
          'endDate': iso(to),
        if (requestType == 'LATE_ARRIVAL' || requestType == 'EARLY_LEAVE') ...{
          'fromTime':
              '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
          'toTime':
              '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
        },
      },
    };
    final payload = canonicalJson(body);
    if (payload != lastPayload) {
      key = commandKey();
      lastPayload = payload;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      WorkflowRecord record;
      if (widget.initial != null) {
        await ref
            .read(workflowRepositoryProvider(widget.kind))
            .saveEntity(
              '/requests',
              body,
              existing: {
                'id': widget.initial!.id,
                'version': widget.initial!.version,
                'etag': widget.initial!.etag,
              },
            );
        record = widget.initial!;
        ref.invalidate(detailProvider((kind: record.kind, id: record.id)));
      } else {
        record = await ref
            .read(workflowUseCasesProvider(widget.kind))
            .create(widget.kind, body, key!);
      }
      ref.invalidate(recordsProvider);
      ref.invalidate(balancesProvider);
      ref.invalidate(approvalProvider);
      if (mounted) {
        setState(() => dirty = false);
        context.pushReplacement('/record/${record.kind}/${record.id}');
        toast(
          context,
          leave || correction ? 'Request sent for approval' : 'Draft saved',
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _FieldButton extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final VoidCallback? onTap;
  const _FieldButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext c) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.centerLeft,
    ),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Palette.muted),
              ),
              Text(value, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    ),
  );
}

class EditRequestPage extends ConsumerWidget {
  final String id;
  const EditRequestPage(this.id, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = detailProvider((kind: 'request', id: id));
    return ref
        .watch(provider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, st) => AppPage(
            title: 'Edit draft',
            children: [
              Text(message(e)),
              TextButton(
                onPressed: () => ref.invalidate(provider),
                child: const Text('Try again'),
              ),
            ],
          ),
          data: (record) =>
              record.status == 'DRAFT' &&
                  record.employeeId == ref.watch(sessionProvider).profile?.id
              ? RequestFormPage('request', initial: record)
              : AppPage(
                  title: 'Draft unavailable',
                  children: const [
                    Text('Only your draft request can be edited.'),
                  ],
                ),
        );
  }
}
