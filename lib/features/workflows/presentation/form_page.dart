import 'dart:typed_data';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:hrflow_mobile/shared/domain/workflow.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/attendance/domain/correction_time.dart';
import 'package:hrflow_mobile/features/leave/presentation/preview_panel.dart';

import 'form_actions.dart';
import 'request_details_fields.dart';
import 'material_request_fields.dart';
import 'workflow_date_fields.dart';
import 'form_review.dart';

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
  bool get supportsFormDrafts =>
      ref.read(workflowRepositoryProvider(widget.kind)).supportsFormDrafts;
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
    if (initial == null && supportsFormDrafts) {
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
    if (widget.initial != null || !supportsFormDrafts) return;
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
    final earliest = DateUtils.dateOnly(
      ref.read(clockProvider)().subtract(const Duration(days: 365)),
    );
    final latest = DateUtils.dateOnly(
      ref.read(clockProvider)().add(const Duration(days: 730)),
    );
    final minimum = first || from.isBefore(earliest)
        ? earliest
        : from.isAfter(latest)
        ? latest
        : DateUtils.dateOnly(from);
    final selected = first ? from : to;
    final initial = selected.isBefore(minimum)
        ? minimum
        : selected.isAfter(latest)
        ? latest
        : selected;
    final picked = await showDatePicker(
      context: context,
      helpText: first ? 'Choose the start date' : 'Choose the end date',
      initialDate: initial,
      firstDate: minimum,
      lastDate: latest,
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
    if (saving) return false;
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
    if (!confirmed || widget.initial != null || !supportsFormDrafts) {
      return confirmed;
    }
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
    final requestTypes = !leave && !correction
        ? ref.watch(collectionProvider('/requests/types')).asData?.value
        : null;
    final requestName =
        requestTypes
            ?.where((row) => row['code'] == requestType)
            .firstOrNull?['name']
            ?.toString() ??
        'Choose a request type';
    final leavePreview = leave && previewQuery != null
        ? ref.watch(leavePreviewProvider(previewQuery!))
        : null;
    return PopScope(
      canPop: !dirty && !saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await discard() && context.mounted) {
          setState(() => dirty = false);
          context.pop();
        }
      },
      child: AppPage(
        canLeave: discard,
        title: leave
            ? 'Request leave'
            : correction
            ? 'Attendance correction'
            : 'New request',
        subtitle: leave
            ? 'Choose your dates and review the chargeable leave before sending.'
            : correction
            ? 'Help your manager understand what needs correcting.'
            : 'A clear request is easier to approve.',
        bottom: FormActions(
          saving: saving,
          draft: !leave && !correction,
          submit: submit,
          error: error,
        ),
        children: [
          if (!supportsFormDrafts)
            const Surface(
              child: Text(
                'Unsaved changes stay on this screen. Draft recovery is not available in this workspace.',
              ),
            ),
          Form(
            key: form,
            onChanged: markDirty,
            child: FocusScope(
              canRequestFocus: !saving,
              child: AbsorbPointer(
                absorbing: saving,
                child: Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (leave)
                        AsyncPanel(
                          value: ref.watch(collectionProvider('/leave/types')),
                          retry: () => ref.invalidate(
                            collectionProvider('/leave/types'),
                          ),
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
                        RequestDetailsFields(
                          title: title,
                          requestType: requestType,
                          locked:
                              widget.initial != null &&
                              !ref.read(clientProvider).isLocal,
                          saving: saving,
                          onTypeChanged: (value) {
                            setState(() => requestType = value);
                            markDirty();
                          },
                        ),
                        if (requestType == 'MATERIAL')
                          MaterialRequestFields(
                            material: material,
                            materialName: materialName,
                            quantity: quantity,
                            additional: additionalMaterials,
                            labels: materialLabels,
                            saving: saving,
                            select: (selected) {
                              setState(() {
                                material = selected.id;
                                materialName = selected.title;
                                materialLabels[selected.id] = selected.title;
                              });
                              markDirty();
                            },
                            remove: (item) {
                              setState(() => additionalMaterials.remove(item));
                              markDirty();
                            },
                            fail: (value) => setState(() => error = value),
                            add: () {
                              final count = int.tryParse(quantity.text);
                              if (count == null || count < 1 || count > 100) {
                                setState(
                                  () =>
                                      error = 'Enter a quantity from 1 to 100.',
                                );
                                return;
                              }
                              setState(() {
                                additionalMaterials.add({
                                  'materialId': material,
                                  'quantity': count,
                                });
                                material = null;
                                materialName = null;
                                quantity.text = '1';
                                error = null;
                              });
                              markDirty();
                            },
                          ),
                      ],
                      WorkflowDateFields(
                        kind: widget.kind,
                        requestType: requestType,
                        portion: portion,
                        from: from,
                        to: to,
                        start: start,
                        end: end,
                        halfDayAllowed: halfDayAllowed,
                        saving: saving,
                        pickDate: date,
                        pickTime: time,
                        changePortion: (value) {
                          setState(() => portion = value);
                          markDirty();
                        },
                      ),
                      if (leave && previewQuery != null) ...[
                        const SizedBox(height: 16),
                        AsyncPanel(
                          value: leavePreview!,
                          retry: () => ref.invalidate(
                            leavePreviewProvider(previewQuery!),
                          ),
                          builder: (preview) => LeavePreviewPanel(
                            preview: preview,
                            evidenceName: evidenceName,
                            chooseEvidence: saving ? null : chooseEvidence,
                          ),
                        ),
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
                      const SizedBox(height: 8),
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
                      AnimatedBuilder(
                        animation: Listenable.merge([title, quantity]),
                        builder: (context, _) => FormReview(
                          key: const ValueKey('form-review'),
                          rows: [
                            if (!leave && !correction)
                              (
                                'Request',
                                title.text.trim().isEmpty
                                    ? 'Enter a request title'
                                    : title.text.trim(),
                              ),
                            (
                              'Type',
                              leave
                                  ? (selectedPolicy?['name']?.toString() ??
                                        'Choose a leave type')
                                  : correction
                                  ? 'Attendance correction'
                                  : requestName,
                            ),
                            if (leave ||
                                correction ||
                                !['GENERAL', 'MATERIAL'].contains(requestType))
                              (
                                'Dates',
                                '${shortDate(iso(from))} → ${shortDate(iso(to))}',
                              ),
                            if (leave)
                              (
                                'Day portion',
                                switch (portion) {
                                  'MORNING' => 'Morning only',
                                  'AFTERNOON' => 'Afternoon only',
                                  _ => 'Full day',
                                },
                              ),
                            if (!leave &&
                                !correction &&
                                requestType == 'MATERIAL')
                              (
                                'Materials',
                                '${additionalMaterials.length + (material == null ? 0 : 1)} selected',
                              ),
                            if (correction ||
                                [
                                  'LATE_ARRIVAL',
                                  'EARLY_LEAVE',
                                ].contains(requestType))
                              (
                                'Times',
                                '${start.format(context)} → ${end.format(context)}',
                              ),
                          ],
                          nextStep: !leave && !correction
                              ? 'Save a draft, then submit it from the request details.'
                              : 'Send these details for approval. The server checks your company rules.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> submit() async {
    if (saving) return;
    final invalid = form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      setState(() => error = 'Check the highlighted fields before continuing.');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && invalid.first.mounted) {
          Scrollable.ensureVisible(invalid.first.context, alignment: .1);
        }
      });
      return;
    }
    setState(() => error = null);
    final leave = widget.kind == 'leave',
        correction = widget.kind == 'correction';
    if (to.isBefore(from)) {
      setState(() => error = 'The end date must follow the start date.');
      return;
    }
    if (leave && from.year != to.year) {
      setState(
        () => error = 'Create a separate leave request for each calendar year.',
      );
      return;
    }
    if (leave && portion != 'FULL_DAY' && from != to) {
      setState(() => error = 'Half-day requests must be on a single date.');
      return;
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
    FocusScope.of(context).unfocus();
    try {
      if (leave && previewQuery != null) {
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
      }
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
        if (supportsFormDrafts) {
          await ref
              .read(workflowRepositoryProvider(widget.kind))
              .clearFormDraft(widget.kind);
        }
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
