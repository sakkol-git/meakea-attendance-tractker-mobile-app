import 'dart:typed_data';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:hrflow_mobile/shared/domain/workflow.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/attendance/domain/correction_time.dart';
import 'package:hrflow_mobile/core/leave_quantity.dart';
import 'package:hrflow_mobile/shared/presentation/case_page.dart';

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
  String? type, material, materialName;
  final materialLabels = <String, String>{};
  final additionalMaterials = <JsonMap>[];
  String portion = 'FULL_DAY', requestType = 'GENERAL';
  late DateTime from, to;
  TimeOfDay start = const TimeOfDay(hour: 8, minute: 30),
      end = const TimeOfDay(hour: 17, minute: 30);
  String? key, lastPayload;
  String? evidenceName;
  Uint8List? evidenceBytes;
  Timer? draftDebounce;
  Future<void> draftWrite = Future.value();
  bool restoring = false;
  bool dirty = false, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final now = ref
        .read(clockProvider)()
        .toUtc()
        .add(CorrectionTime.companyOffset);
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
    if (initial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => restoreDraft());
    }
  }

  @override
  void dispose() {
    draftDebounce?.cancel();
    title.dispose();
    reason.dispose();
    quantity.dispose();
    super.dispose();
  }

  JsonMap draftPayload() => {
    'schema': 1,
    'title': title.text,
    'reason': reason.text,
    'quantity': quantity.text,
    'type': type,
    'material': material,
    'materialName': materialName,
    'materialLabels': materialLabels,
    'additionalMaterials': additionalMaterials,
    'portion': portion,
    'requestType': requestType,
    'from': iso(from),
    'to': iso(to),
    'startHour': start.hour,
    'startMinute': start.minute,
    'endHour': end.hour,
    'endMinute': end.minute,
  };

  void markDirty() {
    if (restoring) return;
    dirty = true;
    if (widget.initial != null) return;
    draftDebounce?.cancel();
    final repository = ref.read(workflowRepositoryProvider(widget.kind));
    draftDebounce = Timer(const Duration(milliseconds: 400), () {
      final payload = draftPayload();
      draftWrite = draftWrite
          .then((_) => repository.saveFormDraft(widget.kind, payload))
          .catchError((Object failure) {
            if (mounted) {
              setState(
                () => error = 'Draft could not be saved: ${message(failure)}',
              );
            }
          });
    });
  }

  Future<void> restoreDraft() async {
    try {
      final saved = await ref
          .read(workflowRepositoryProvider(widget.kind))
          .readFormDraft(widget.kind);
      if (!mounted || dirty || saved == null || saved['schema'] != 1) return;
      restoring = true;
      setState(() {
        title.text = saved['title'] as String? ?? '';
        reason.text = saved['reason'] as String? ?? '';
        quantity.text = saved['quantity'] as String? ?? '1';
        type = saved['type'] as String?;
        material = saved['material'] as String?;
        materialName = saved['materialName'] as String?;
        materialLabels
          ..clear()
          ..addAll(
            (saved['materialLabels'] as Map? ?? {}).map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ),
          );
        additionalMaterials
          ..clear()
          ..addAll(
            (saved['additionalMaterials'] as List? ?? []).map(
              (item) => JsonMap.from(item as Map),
            ),
          );
        portion = saved['portion'] as String? ?? 'FULL_DAY';
        requestType = saved['requestType'] as String? ?? 'GENERAL';
        from = DateTime.tryParse(saved['from'] as String? ?? '') ?? from;
        to = DateTime.tryParse(saved['to'] as String? ?? '') ?? to;
        start = TimeOfDay(
          hour: saved['startHour'] as int? ?? 8,
          minute: saved['startMinute'] as int? ?? 30,
        );
        end = TimeOfDay(
          hour: saved['endHour'] as int? ?? 17,
          minute: saved['endMinute'] as int? ?? 30,
        );
        dirty = true;
      });
      restoring = false;
    } catch (failure) {
      if (mounted) {
        setState(() => error = 'Draft recovery failed: ${message(failure)}');
      }
    }
  }

  Future<void> date(bool first) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: first ? from : to,
      firstDate: ref.read(clockProvider)().subtract(const Duration(days: 365)),
      lastDate: ref.read(clockProvider)().add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() {
        if (first) {
          from = picked;
          if (to.isBefore(from)) to = from;
        } else {
          to = picked;
        }
      });
      markDirty();
    }
  }

  Future<void> time(bool first) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: first ? start : end,
    );
    if (picked != null) {
      setState(() {
        if (first) {
          start = picked;
        } else {
          end = picked;
        }
      });
      markDirty();
    }
  }

  String iso(DateTime d) => d.toIso8601String().substring(0, 10);
  LeavePreviewQuery? get previewQuery => type == null
      ? null
      : (typeId: type!, from: iso(from), to: iso(to), portion: portion);

  Future<void> chooseEvidence() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (picked.isEmpty || !mounted) return;
    final file = picked.first;
    final length = await file.length();
    if (length == null || length > 10 * 1024 * 1024) {
      setState(() => error = 'Choose a PDF or image smaller than 10 MB.');
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      evidenceName = file.name;
      evidenceBytes = bytes;
      dirty = true;
      error = null;
    });
  }

  Future<bool> discard() async {
    if (!dirty) return true;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text('Discard this draft?'),
            content: Text('Your unsaved changes will be lost.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || widget.initial != null) return confirmed;
    draftDebounce?.cancel();
    try {
      await draftWrite;
      await ref
          .read(workflowRepositoryProvider(widget.kind))
          .clearFormDraft(widget.kind);
      return true;
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = 'Could not discard server draft: ${message(failure)}',
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final leave = widget.kind == 'leave',
        correction = widget.kind == 'correction';
    final selectedPolicy = ref
        .watch(collectionProvider('/leave/types'))
        .asData
        ?.value
        .where((row) => row['id'] == type)
        .firstOrNull;
    final halfDayAllowed =
        selectedPolicy != null && selectedPolicy['allowHalfDay'] != false;
    final leavePreview = leave && previewQuery != null
        ? ref.watch(leavePreviewProvider(previewQuery!))
        : null;
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
            onChanged: markDirty,
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
                            : (v) => setState(() {
                                type = v;
                                if (types.firstWhere(
                                      (row) => row['id'] == v,
                                    )['allowHalfDay'] ==
                                    false) {
                                  portion = 'FULL_DAY';
                                }
                              }),
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
                      FormField<String>(
                        key: ValueKey(
                          'material-${additionalMaterials.length}-$material',
                        ),
                        initialValue: material,
                        validator: (value) =>
                            value == null && additionalMaterials.isEmpty
                            ? 'Choose a material'
                            : null,
                        builder: (field) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Material · Required'),
                            OutlinedButton.icon(
                              icon: Icon(Icons.search),
                              label: Text(
                                materialName ?? material ?? 'Search materials',
                              ),
                              onPressed: saving
                                  ? null
                                  : () async {
                                      final selected =
                                          await showPagedCaseLookup(
                                            context,
                                            'requests.inventory',
                                            'material',
                                          );
                                      if (selected == null || !mounted) return;
                                      if (additionalMaterials.any(
                                        (item) =>
                                            item['materialId'] == selected.id,
                                      )) {
                                        setState(
                                          () => error =
                                              'This material is already added.',
                                        );
                                        return;
                                      }
                                      setState(() {
                                        material = selected.id;
                                        materialName = selected.title;
                                        materialLabels[selected.id] =
                                            selected.title;
                                      });
                                      field.didChange(selected.id);
                                      markDirty();
                                    },
                            ),
                            if (field.hasError)
                              Text(
                                field.errorText!,
                                style: TextStyle(color: context.semantic.error),
                              ),
                          ],
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
                              materialLabels[item['materialId']] ??
                                  item['materialId']?.toString() ??
                                  'Material',
                            ),
                            subtitle: Text('Quantity: ${item['quantity']}'),
                            trailing: IconButton(
                              tooltip: 'Remove material',
                              onPressed: saving
                                  ? null
                                  : () {
                                      setState(
                                        () => additionalMaterials.remove(item),
                                      );
                                      markDirty();
                                    },
                              icon: Icon(Icons.close),
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
                                  materialName = null;
                                  quantity.text = '1';
                                  error = null;
                                });
                                markDirty();
                              },
                        icon: Icon(Icons.add),
                        label: Text('Add another material'),
                      ),
                    ],
                  ],
                  if (leave ||
                      correction ||
                      requestType != 'GENERAL' &&
                          requestType != 'MATERIAL') ...[
                    const SizedBox(height: 20),
                    _FieldButton(
                      label: correction ? 'Correct clock-in date' : 'From',
                      value: shortDate(iso(from)),
                      icon: Icons.calendar_today_outlined,
                      onTap: saving ? null : () => date(true),
                    ),
                    if (leave ||
                        correction ||
                        requestType == 'REMOTE_WORK') ...[
                      const SizedBox(height: 12),
                      _FieldButton(
                        label: correction ? 'Correct clock-out date' : 'To',
                        value: shortDate(iso(to)),
                        icon: Icons.calendar_today_outlined,
                        onTap: saving ? null : () => date(false),
                      ),
                    ],
                    if (leave && halfDayAllowed) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        itemHeight: null,
                        initialValue: portion,
                        decoration: const InputDecoration(
                          labelText: 'Day portion',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'FULL_DAY',
                            child: Text('Full day'),
                          ),
                          DropdownMenuItem(
                            value: 'MORNING',
                            child: Text('Morning only'),
                          ),
                          DropdownMenuItem(
                            value: 'AFTERNOON',
                            child: Text('Afternoon only'),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (v) => setState(() => portion = v!),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Weekends and company holidays are excluded in the demo. Your company’s policy determines the final balance.',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.semantic.textMuted,
                        ),
                      ),
                    ],
                    if (leave && previewQuery != null) ...[
                      const SizedBox(height: 16),
                      AsyncPanel(
                        value: leavePreview!,
                        retry: () =>
                            ref.invalidate(leavePreviewProvider(previewQuery!)),
                        builder: (preview) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Before you submit',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            InfoRow(
                              'Chargeable',
                              formatLeaveDays(preview.chargeableDays),
                            ),
                            InfoRow(
                              'Available before',
                              formatLeaveDays(preview.balanceBefore),
                            ),
                            InfoRow(
                              'Balance after',
                              formatLeaveDays(preview.balanceAfter),
                            ),
                            if (preview.minimumNoticeDays > 0)
                              InfoRow(
                                'Minimum notice',
                                '${preview.minimumNoticeDays} days',
                              ),
                            for (final warning in preview.warnings)
                              Text(
                                warning,
                                style: TextStyle(color: context.semantic.error),
                              ),
                            if (preview.evidenceRequired) ...[
                              Text(
                                'Supporting evidence is required before submission.',
                              ),
                              OutlinedButton.icon(
                                onPressed: saving ? null : chooseEvidence,
                                icon: Icon(Icons.attach_file),
                                label: Text(
                                  evidenceName ?? 'Choose PDF or image',
                                ),
                              ),
                            ],
                          ],
                        ),
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
                      if (correction) ...[
                        const SizedBox(height: 12),
                        Text('Company time zone: Asia/Phnom_Penh (UTC+07)'),
                        if (iso(to) != iso(from))
                          Text(
                            'Ends next day',
                            key: Key('correction-next-day'),
                          ),
                        const SizedBox(height: 12),
                        Text('Original recorded time'),
                        AsyncPanel(
                          value: ref.watch(sessionsProvider),
                          retry: () => ref.invalidate(sessionsProvider),
                          builder: (sessions) {
                            final originals = sessions.where((s) {
                              final day = s.clockIn.toUtc().add(
                                CorrectionTime.companyOffset,
                              );
                              return iso(day) == iso(from);
                            }).toList();
                            if (originals.isEmpty) {
                              return Text('No recorded session on this date');
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final s in originals)
                                  Text(
                                    '${CorrectionTime.display(s.clockIn)} → ${CorrectionTime.display(s.clockOut)}',
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Proposed: ${CorrectionTime.display(CorrectionTime.instant(from, start.hour, start.minute))} → ${CorrectionTime.display(CorrectionTime.instant(to, end.hour, end.minute))}',
                        ),
                      ],
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
                        style: TextStyle(color: context.semantic.error),
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
                        : Icon(Icons.arrow_forward),
                    label: Text(
                      saving
                          ? 'Saving…'
                          : !leave && !correction
                          ? 'Save request draft'
                          : 'Send for approval',
                    ),
                  ),
                  if (!leave && !correction)
                    Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'You can add attachments and review the draft before submitting.',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.semantic.textMuted,
                        ),
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
    if (leave && portion != 'FULL_DAY' && from != to) {
      setState(() => error = 'Half-day requests must be on a single date.');
      return;
    }
    if (leave && previewQuery != null) {
      try {
        final preview = await ref.read(
          leavePreviewProvider(previewQuery!).future,
        );
        if (!mounted) return;
        if (preview.warnings.isNotEmpty) {
          setState(() => error = preview.warnings.first);
          return;
        }
        if (preview.evidenceRequired && evidenceBytes == null) {
          setState(
            () => error = 'Supporting evidence is required before submission.',
          );
          return;
        }
      } catch (failure) {
        if (mounted) setState(() => error = message(failure));
        return;
      }
    }
    if (correction) {
      final problem = CorrectionTime.validate(
        CorrectionTime.instant(from, start.hour, start.minute),
        CorrectionTime.instant(to, end.hour, end.minute),
        ref.read(clockProvider)(),
      );
      if (problem != null) {
        setState(() => error = problem);
        return;
      }
    }
    if (!correction &&
        (requestType == 'LATE_ARRIVAL' || requestType == 'EARLY_LEAVE') &&
        (end.hour * 60 + end.minute <= start.hour * 60 + start.minute)) {
      setState(() => error = 'The end time must follow the start time.');
      return;
    }
    String stamp(DateTime date, TimeOfDay t) =>
        CorrectionTime.instant(date, t.hour, t.minute).toIso8601String();
    final body = <String, dynamic>{
      'reason': reason.text.trim(),
      if (leave) ...{
        'leaveTypeId': type,
        'startDate': iso(from),
        'endDate': iso(to),
        'portion': portion,
      },
      if (correction) ...{
        'workDate': iso(from),
        'newCheckIn': stamp(from, start),
        'newCheckOut': stamp(to, end),
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
      draftDebounce?.cancel();
      await draftWrite;
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
        if (leave && evidenceBytes != null) {
          await ref
              .read(workflowRepositoryProvider('leave'))
              .attach(record, evidenceName!, evidenceBytes!);
        }
        await ref
            .read(workflowRepositoryProvider(widget.kind))
            .clearFormDraft(widget.kind);
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
                style: TextStyle(fontSize: 12, color: c.semantic.textMuted),
              ),
              Text(value, style: TextStyle(fontSize: 16)),
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
                child: Text('Try again'),
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
