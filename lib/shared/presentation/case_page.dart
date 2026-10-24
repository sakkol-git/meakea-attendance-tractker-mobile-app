import '../../features/reporting/presentation/export_button.dart';

import 'package:go_router/go_router.dart';

import '../../features/notifications/application/push.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/cases.dart';
import '../../app/providers.dart';
import '../../core/protocol.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../core/leave_quantity.dart';
import '../domain/cases.dart';
import '../domain/models.dart';

enum FieldKind {
  text,
  email,
  number,
  integer,
  date,
  time,
  note,
  choice,
  lookup,
  toggle,
  weekdays,
}

class CaseField {
  final String key, label;
  final FieldKind kind;
  final bool required;
  final Map<String, String> choices;
  final String? lookup;
  final String valueField;
  final Object? initial;
  final num? minimum, maximum;
  const CaseField(
    this.key,
    this.label, {
    this.kind = FieldKind.text,
    this.required = true,
    this.choices = const {},
    this.lookup,
    this.valueField = 'id',
    this.initial,
    this.minimum,
    this.maximum,
  });
}

class CaseAction {
  final String key, label;
  final List<CaseField> fields;
  final List<String> inherit;
  final String? targetField, prepare;
  final bool destructive;
  final bool Function(CaseRecord?, Profile)? when;
  const CaseAction(
    this.key,
    this.label, {
    this.fields = const [],
    this.inherit = const [],
    this.targetField,
    this.prepare,
    this.destructive = false,
    this.when,
  });
}

class CasePanel {
  final String key, title, description;
  final Map<String, String> details;
  final List<CaseAction> actions;
  final CaseAction? create;
  final bool dates;
  final String access;
  const CasePanel(
    this.key,
    this.title,
    this.description, {
    this.details = const {},
    this.actions = const [],
    this.create,
    this.dates = false,
    this.access = 'hr',
  });
}

class FeatureCasesPage extends ConsumerStatefulWidget {
  final CasePanel panel;
  const FeatureCasesPage(this.panel, {super.key});
  @override
  ConsumerState<FeatureCasesPage> createState() => _FeatureCasesState();
}

class _FeatureCasesState extends ConsumerState<FeatureCasesPage> {
  String search = '';
  DateTimeRange? period;
  Timer? debounce;
  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final panel = widget.panel;
    final query = (
      collection: panel.key,
      search: search,
      from: period?.start.toIso8601String().substring(0, 10) ?? '',
      to: period?.end.toIso8601String().substring(0, 10) ?? '',
    );
    final provider = caseRowsProvider(query),
        actor = ref.watch(sessionProvider).profile!;
    return AppPage(
      title: panel.title,
      subtitle: panel.description,
      actions: [
        if (panel.dates)
          IconButton(
            tooltip: 'Choose report period',
            icon: Icon(Icons.date_range_outlined),
            onPressed: () async {
              final now = ref.read(clockProvider)();
              final value = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(now.year + 2, 12, 31),
                initialDateRange: period,
              );
              if (value != null && mounted) setState(() => period = value);
            },
          ),
      ],
      onRefresh: () async {
        ref.invalidate(provider);
        await ref.read(provider.future);
      },
      children: [
        if (panel.key == 'attendance.evidence')
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: FilledButton.icon(
              onPressed: () => context.push('/evidence/capture'),
              icon: Icon(Icons.my_location),
              label: Text('Submit observation'),
            ),
          ),
        if (panel.key == 'notifications.devices') ...[
          BusyButton(
            label: 'Enable notifications on this device',
            action: () async {
              await ref.read(pushRegistrationProvider.notifier).enable();
              final result = ref.read(pushRegistrationProvider);
              if (result.hasError) throw result.error!;
              ref.invalidate(provider);
            },
          ),
          const SizedBox(height: 20),
        ],
        if (panel.create != null &&
            (panel.create!.when?.call(null, actor) ?? true))
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: FilledButton.icon(
              icon: Icon(Icons.add),
              label: Text(panel.create!.label),
              onPressed: () =>
                  showCaseEditor(context, ref, panel.create!, null),
            ),
          ),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search records',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            debounce?.cancel();
            debounce = Timer(const Duration(milliseconds: 300), () {
              if (mounted) setState(() => search = value.trim());
            });
          },
        ),
        if (period != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: InputChip(
              label: Text(
                '${shortDate(period!.start.toString())} – ${shortDate(period!.end.toString())}',
              ),
              onDeleted: () => setState(() => period = null),
            ),
          ),
        const SizedBox(height: 20),
        AsyncPanel(
          value: ref.watch(provider),
          retry: () => ref.invalidate(provider),
          builder: (rows) => rows.isEmpty
              ? const EmptyState(
                  title: 'No records found',
                  description: 'New activity will appear here. Try another search or period.',
                )
              : Column(
                  children: [
                    for (final row in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Surface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                row.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: StatusPill(row.status),
                              ),
                              for (final detail in panel.details.entries)
                                if (row.values[detail.key] != null)
                                  InfoRow(
                                    detail.value,
                                    businessDetail(
                                      detail.key,
                                      row.values[detail.key],
                                    ),
                                  ),
                              if (row.values['message'] is String)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(row.values['message'] as String),
                                ),
                              if (panel.key == 'reporting.exports' &&
                                  row.status == 'COMPLETED')
                                ExportDownloadButton(row.id),
                              for (final action in panel.actions)
                                if (action.when?.call(row, actor) ?? true)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: OutlinedButton(
                                      onPressed: () => showCaseEditor(
                                        context,
                                        ref,
                                        action,
                                        row,
                                      ),
                                      child: Text(action.label),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        if (ref.read(provider.notifier).more)
          BusyButton(
            label: 'Load more',
            action: () => ref.read(provider.notifier).loadMore(),
          ),
      ],
    );
  }
}

String businessValue(Object? value) {
  if (value == null) return '—';
  if (value is bool) return value ? 'Enabled' : 'Disabled';
  if (value is List) {
    return value.where((v) => v is String || v is num).join(' · ');
  }
  if (value is num) return value.toString();
  return statusLabel(value.toString());
}

String businessDetail(String key, Object? value) {
  if (value == null) return '—';
  if ({
    'createdAt',
    'updatedAt',
    'registeredAt',
    'lastSeenAt',
    'deliveredAt',
    'at',
    'generatedAt',
    'asOf',
  }.contains(key)) {
    return companyTimestamp(value.toString());
  }
  if ({
    'date',
    'workDate',
    'startDate',
    'endDate',
    'validFrom',
    'validTo',
    'hireDate',
    'effectiveDate',
    'terminationDate',
  }.contains(key)) {
    return shortDate(value.toString());
  }
  return businessValue(value);
}

Future<void> showCaseEditor(
  BuildContext context,
  WidgetRef ref,
  CaseAction action,
  CaseRecord? record,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _CaseEditor(action, record),
);

class _CaseEditor extends ConsumerStatefulWidget {
  final CaseAction action;
  final CaseRecord? record;
  const _CaseEditor(this.action, this.record);
  @override
  ConsumerState<_CaseEditor> createState() => _CaseEditorState();
}

class _CaseEditorState extends ConsumerState<_CaseEditor> {
  final form = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  final values = <String, dynamic>{};
  final lookupLabels = <String, String>{};
  bool busy = false, review = false, dirty = false;
  String? error, fingerprint;
  Map<String, dynamic>? prepared;
  String previewSearch = '';
  int previewPage = 0;
  @override
  void initState() {
    super.initState();
    for (final field in widget.action.fields) {
      var initial =
          widget.record?.values[field.key] ??
          (field.key == 'annualDays'
              ? widget.record?.values['entitled']
              : null) ??
          field.initial;
      if (initial == '@year') initial = ref.read(clockProvider)().year;
      if (initial == '@today') {
        initial = ref.read(clockProvider)().toIso8601String().substring(0, 10);
      }
      if (field.kind == FieldKind.toggle || field.kind == FieldKind.weekdays) {
        values[field.key] = initial ?? false;
      } else if (field.kind == FieldKind.choice ||
          field.kind == FieldKind.lookup) {
        values[field.key] = initial?.toString();
      } else {
        controllers[field.key] = TextEditingController(
          text: initial?.toString() ?? '',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<bool> discard() async {
    if (!dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text('Discard ${widget.action.label.toLowerCase()}?'),
            content: const Text(
              'Your unsaved changes in this form will be lost.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Discard changes'),
              ),
            ],
          ),
        ) ??
        false;
  }

  bool validDate(String value) {
    final d = DateTime.tryParse(value);
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
        d != null &&
        d.toIso8601String().substring(0, 10) == value;
  }

  String? validate(CaseField field, String? input) {
    final value = input?.trim() ?? '';
    if (value.isEmpty) return field.required ? 'This field is required' : null;
    if (field.kind == FieldKind.email &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      return 'Enter a valid email';
    }
    if (field.kind == FieldKind.date && !validDate(value)) {
      return 'Use a valid YYYY-MM-DD date';
    }
    if (field.kind == FieldKind.time &&
        !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) {
      return 'Use HH:mm';
    }
    if ([FieldKind.number, FieldKind.integer].contains(field.kind)) {
      final number = num.tryParse(value);
      if (number == null ||
          !number.isFinite ||
          (field.kind == FieldKind.integer && number % 1 != 0)) {
        return 'Enter a valid number';
      }
      if (field.minimum != null && number < field.minimum!) {
        return 'Minimum ${field.minimum}';
      }
      if (field.maximum != null && number > field.maximum!) {
        return 'Maximum ${field.maximum}';
      }
    }
    if (field.kind == FieldKind.note && value.length < 5) {
      return 'Give a clear reason with at least 5 characters';
    }
    return null;
  }

  Future<void> selectDate(CaseField field) async {
    final now = ref.read(clockProvider)(), raw = controllers[field.key]!.text;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      initialDate: validDate(raw)
          ? DateTime.parse(raw)
          : DateTime(now.year, now.month, now.day),
    );
    if (picked != null && mounted) {
      setState(
        () => controllers[field.key]!.text = picked.toIso8601String().substring(
          0,
          10,
        ),
      );
    }
  }

  Future<void> selectTime(CaseField field) async {
    final raw = controllers[field.key]!.text.split(':');
    final hour = raw.length == 2 ? int.tryParse(raw[0]) : null;
    final minute = raw.length == 2 ? int.tryParse(raw[1]) : null;
    final picked = await showTimePicker(
      context: context,
      initialTime:
          hour != null &&
              minute != null &&
              hour >= 0 &&
              hour < 24 &&
              minute >= 0 &&
              minute < 60
          ? TimeOfDay(hour: hour, minute: minute)
          : const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null && mounted) {
      setState(
        () => controllers[field.key]!.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
      );
      dirty = true;
    }
  }

  Map<String, dynamic> payload() => {
    for (final key in widget.action.inherit)
      if (widget.record?.values[key] != null) key: widget.record!.values[key],
    ...values,
    for (final field in widget.action.fields)
      if (controllers.containsKey(field.key))
        field.key: controllers[field.key]!.text.trim().isEmpty
            ? null
            : [FieldKind.number, FieldKind.integer].contains(field.kind)
            ? num.parse(controllers[field.key]!.text.trim())
            : controllers[field.key]!.text.trim(),
  };
  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final action = widget.action,
        body = payload(),
        actor = ref.read(sessionProvider).profile!;
    if (!(action.when?.call(widget.record, actor) ?? true)) {
      setState(
        () => error = 'This action is no longer available to your account.',
      );
      return;
    }
    final hash = canonicalJson(body);
    if (fingerprint != hash) {
      fingerprint = hash;
      prepared = null;
      review = false;
    }
    final gateway = ref.read(caseGatewayProvider(action.key.split('.').first));
    final id = action.targetField == null
        ? widget.record?.id
        : widget.record?.values[action.targetField]?.toString();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final keys = ref.read(pendingCommandKeysProvider);
      final scope = '${actor.tenantId}:${actor.id}:case:${action.key}:$id';
      final stage = review && prepared != null ? 'commit' : 'command';
      final key = await keys.acquire('$scope:$stage', {
        'action': action.key,
        'etag': widget.record?.etag,
        'body': body,
        if (prepared?['previewId'] != null) 'previewId': prepared!['previewId'],
      });
      if (!review) {
        if (action.prepare != null) {
          prepared = await gateway.changeCase(
            action.prepare!,
            id,
            body,
            key: key,
            etag: widget.record?.etag,
          );
        }
        if (mounted) setState(() => review = true);
        return;
      }
      await gateway.changeCase(
        action.key,
        id,
        {
          ...body,
          if (prepared?['previewId'] != null)
            'previewId': prepared!['previewId'],
        },
        key: key,
        etag: widget.record?.etag,
      );
      await keys.clear('$scope:command');
      await keys.clear('$scope:commit');
      if (!mounted) return;
      dirty = false;
      ref.invalidate(caseRowsProvider);
      ref.invalidate(caseOptionsProvider);
      ref.invalidate(balancesProvider);
      ref.invalidate(recordsProvider);
      ref.invalidate(todayProvider);
      ref.invalidate(collectionProvider);
      ref.invalidate(shiftAssignmentsProvider);
      toast(context, 'Changes saved');
      Navigator.pop(context);
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = switch (writeFailureKind(failure)) {
            WriteFailureKind.conflict => 'This record changed. Keep your inputs, review the latest record, then submit again.',
            WriteFailureKind.unknown => 'Outcome unknown. Check the record before retrying; the same command key will be reused.',
            WriteFailureKind.failed => message(failure),
          },
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    return PopScope(
      canPop: !busy && !dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && !busy && await discard() && mounted) {
          setState(() => dirty = false);
          Navigator.pop(this.context);
        }
      },
      child: AlertDialog(
        title: Text(
          review ? 'Review ${action.label.toLowerCase()}' : action.label,
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: form,
            onChanged: () => dirty = true,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.record != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        widget.record!.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  if (review) ...[
                    for (final field in action.fields)
                      InfoRow(field.label, reviewLabel(field)),
                    if (action.key == 'leave.adjust' &&
                        widget.record != null) ...[
                      InfoRow(
                        'Current balance',
                        formatLeaveDays(
                          widget.record!.values['available'] as num?,
                        ),
                      ),
                      InfoRow(
                        'Change',
                        formatLeaveDays(payload()['delta'] as num?),
                      ),
                      InfoRow(
                        'Resulting balance',
                        formatLeaveDays(
                          (widget.record!.values['available'] as num? ?? 0) +
                              (payload()['delta'] as num? ?? 0),
                        ),
                      ),
                    ],
                    if (prepared?['employeeName'] != null) ...[
                      InfoRow('Employee', prepared!['employeeName'].toString()),
                      InfoRow(
                        'Current access',
                        prepared!['currentRole'].toString(),
                      ),
                      if (prepared!['newRole'] != null)
                        InfoRow('New access', prepared!['newRole'].toString()),
                      if (prepared!['accessEnds'] == true)
                        const InfoRow('Access', 'Ends on the effective date'),
                      InfoRow(
                        'Pending requests',
                        '${prepared!['pendingRequests']}',
                      ),
                      InfoRow(
                        'Assigned materials',
                        '${prepared!['assignedMaterials']}',
                      ),
                      InfoRow(
                        'Open approvals',
                        '${prepared!['openApprovals']}',
                      ),
                    ],
                    if (prepared?['summary'] != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(prepared!['summary'].toString()),
                      ),
                    if (prepared?['rows'] is List) ...buildPreviewRows(),
                    Text(
                      action.destructive
                          ? 'This action changes access or removes a resource. Your reason is recorded in the audit history.'
                          : 'Confirm these changes. A reason and the resulting action are recorded where required.',
                    ),
                  ] else
                    for (final field in action.fields)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: buildField(field),
                      ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: TextStyle(color: context.semantic.error),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy
                ? null
                : () async {
                    if (review) {
                      setState(() {
                        review = false;
                        prepared = null;
                      });
                    } else {
                      if (await discard() && context.mounted) {
                        setState(() => dirty = false);
                        Navigator.pop(context);
                      }
                    }
                  },
            child: Text(review ? 'Revise' : 'Go back'),
          ),
          if (action.destructive)
            OutlinedButton(
              onPressed: busy ? null : submit,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.semantic.error,
                side: BorderSide(color: context.semantic.error),
              ),
              child: Text(
                busy
                    ? 'Saving…'
                    : review
                    ? action.label
                    : 'Review impact',
              ),
            )
          else
            FilledButton(
              onPressed: busy ? null : submit,
              child: Text(
                busy
                    ? 'Saving…'
                    : review
                    ? action.label
                    : 'Review changes',
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> buildPreviewRows() {
    final rows = (prepared!['rows'] as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .where(
          (row) => '${row['employeeName']} ${row['leaveTypeName']}'
              .toLowerCase()
              .contains(previewSearch.toLowerCase()),
        )
        .toList();
    final start = previewPage * 10;
    final visible = rows.skip(start).take(10);
    return [
      InfoRow('Employees affected', '${prepared!['affectedEmployees']}'),
      InfoRow(
        'Total carried',
        formatLeaveDays(prepared!['totalCarried'] as num?),
      ),
      InfoRow(
        'Total forfeited',
        formatLeaveDays(prepared!['totalForfeited'] as num?),
      ),
      const SizedBox(height: 12),
      TextField(
        decoration: const InputDecoration(
          labelText: 'Search preview',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (value) => setState(() {
          previewSearch = value.trim();
          previewPage = 0;
        }),
      ),
      const SizedBox(height: 8),
      Text('${rows.length} employee/type rows · page ${previewPage + 1}'),
      for (final row in visible)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row['employeeName']} · ${row['leaveTypeName']}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                InfoRow(
                  'Current',
                  formatLeaveDays(row['currentBalance'] as num?),
                ),
                InfoRow('Carry', formatLeaveDays(row['carriedOver'] as num?)),
                InfoRow('Forfeit', formatLeaveDays(row['forfeited'] as num?)),
                InfoRow(
                  'New balance',
                  formatLeaveDays(row['newBalance'] as num?),
                ),
              ],
            ),
          ),
        ),
      Row(
        children: [
          TextButton(
            onPressed: previewPage == 0
                ? null
                : () => setState(() => previewPage--),
            child: const Text('Previous rows'),
          ),
          TextButton(
            onPressed: start + 10 >= rows.length
                ? null
                : () => setState(() => previewPage++),
            child: const Text('Next rows'),
          ),
        ],
      ),
    ];
  }

  String reviewLabel(CaseField field) {
    final value = payload()[field.key];
    if (field.kind == FieldKind.weekdays) {
      return [
        for (var i = 0; i < 7; i++)
          if (((value as int? ?? 0) & (1 << i)) != 0)
            const [
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
              'Sunday',
            ][i],
      ].join(', ');
    }
    if (field.kind == FieldKind.choice) {
      return field.choices[value] ?? businessValue(value);
    }
    if (field.kind == FieldKind.date) return shortDate(value?.toString());
    if (field.kind == FieldKind.lookup) {
      return lookupLabels[field.key] ??
          widget
              .record
              ?.values['${field.key.replaceFirst(RegExp(r'Id$'), '')}Name']
              ?.toString() ??
          value?.toString() ??
          'No selection';
    }
    return businessValue(value);
  }

  Widget buildField(CaseField field) {
    if (field.kind == FieldKind.weekdays) {
      return FormField<int>(
        initialValue: values[field.key] as int? ?? 31,
        validator: (v) => (v ?? 0) == 0 ? 'Choose at least one workday' : null,
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 0; i < 7; i++)
                  FilterChip(
                    label: Text(
                      const [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ][i],
                    ),
                    selected:
                        ((values[field.key] as int? ?? 31) & (1 << i)) != 0,
                    onSelected: busy
                        ? null
                        : (selected) {
                            setState(() {
                              final current = values[field.key] as int? ?? 31;
                              values[field.key] = selected
                                  ? current | (1 << i)
                                  : current & ~(1 << i);
                              state.didChange(values[field.key]);
                            });
                          },
                  ),
              ],
            ),
            if (state.hasError)
              Text(
                state.errorText!,
                style: TextStyle(color: context.semantic.error),
              ),
          ],
        ),
      );
    }
    if (field.kind == FieldKind.toggle) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(field.label),
        value: values[field.key] as bool? ?? false,
        onChanged: busy ? null : (v) => setState(() => values[field.key] = v),
      );
    }
    if (field.kind == FieldKind.choice) return choice(field, field.choices);
    if (field.kind == FieldKind.lookup) {
      return FormField<String>(
        initialValue: values[field.key] as String?,
        validator: (v) => field.required && (v == null || v.isEmpty)
            ? 'Choose ${field.label.toLowerCase()}'
            : null,
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${field.label} · ${field.required ? 'Required' : 'Optional'}',
            ),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final selected = await showPagedCaseLookup(
                        context,
                        field.lookup!,
                        field.label,
                      );
                      if (selected == null || !mounted) return;
                      final id = field.valueField == 'id'
                          ? selected.id
                          : selected.values[field.valueField]?.toString();
                      setState(() {
                        values[field.key] = id;
                        lookupLabels[field.key] = selected.title;
                        dirty = true;
                      });
                      state.didChange(id);
                    },
              icon: Icon(Icons.search),
              label: Text(
                lookupLabels[field.key] ??
                    widget
                        .record
                        ?.values['${field.key.replaceFirst(RegExp(r'Id$'), '')}Name']
                        ?.toString() ??
                    (values[field.key]?.toString() ??
                        'Search ${field.label.toLowerCase()}'),
              ),
            ),
            if (state.hasError)
              Text(
                state.errorText!,
                style: TextStyle(color: context.semantic.error),
              ),
          ],
        ),
      );
    }
    return TextFormField(
      controller: controllers[field.key],
      enabled: !busy,
      maxLines: field.kind == FieldKind.note ? 3 : 1,
      keyboardType: field.kind == FieldKind.email
          ? TextInputType.emailAddress
          : [FieldKind.integer, FieldKind.number].contains(field.kind)
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.required ? 'Required' : 'Optional',
        suffixIcon: field.kind == FieldKind.date
            ? IconButton(
                tooltip: 'Choose ${field.label.toLowerCase()}',
                onPressed: busy ? null : () => selectDate(field),
                icon: Icon(Icons.calendar_today_outlined),
              )
            : field.kind == FieldKind.time
            ? IconButton(
                tooltip: 'Choose ${field.label.toLowerCase()}',
                onPressed: busy ? null : () => selectTime(field),
                icon: Icon(Icons.schedule_outlined),
              )
            : null,
      ),
      validator: (v) => validate(field, v),
    );
  }

  Widget choice(CaseField field, Map<String, String> choices) {
    final current = values[field.key] as String?;
    return DropdownButtonFormField<String>(
      initialValue: choices.containsKey(current) ? current : null,
      isExpanded: true,
      itemHeight: null,
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.required ? 'Required' : 'Optional',
      ),
      items: choices.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: busy ? null : (v) => values[field.key] = v,
      validator: (v) => field.required && v == null
          ? 'Choose ${field.label.toLowerCase()}'
          : null,
    );
  }
}

Future<CaseRecord?> showPagedCaseLookup(
  BuildContext context,
  String collection,
  String label,
) => showDialog<CaseRecord>(
  context: context,
  builder: (_) => _PagedLookupDialog(collection, label),
);

class _PagedLookupDialog extends ConsumerStatefulWidget {
  final String collection, label;
  const _PagedLookupDialog(this.collection, this.label);
  @override
  ConsumerState<_PagedLookupDialog> createState() => _PagedLookupDialogState();
}

class _PagedLookupDialogState extends ConsumerState<_PagedLookupDialog> {
  String search = '';
  int page = 0;
  Timer? debounce;
  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = caseLookupPageProvider((
      collection: widget.collection,
      search: search,
      page: page,
    ));
    final value = ref.watch(provider);
    return AlertDialog(
      title: Text('Choose ${widget.label.toLowerCase()}'),
      content: SizedBox(
        width: 480,
        height: 460,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search all records',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (text) {
                debounce?.cancel();
                debounce = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    setState(() {
                      search = text.trim();
                      page = 0;
                    });
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AsyncPanel(
                value: value,
                retry: () => ref.invalidate(provider),
                builder: (rows) => rows.isEmpty
                    ? const Center(child: Text('No matches'))
                    : ListView(
                        children: [
                          for (final row in rows)
                            ListTile(
                              title: Text(row.title),
                              subtitle: Text(row.id),
                              onTap: () => Navigator.pop(context, row),
                            ),
                        ],
                      ),
              ),
            ),
            if (value.asData != null)
              Row(
                children: [
                  Text('Page ${page + 1}'),
                  const Spacer(),
                  TextButton(
                    onPressed: page == 0 ? null : () => setState(() => page--),
                    child: const Text('Previous'),
                  ),
                  TextButton(
                    onPressed: value.asData!.value.length < 25
                        ? null
                        : () => setState(() => page++),
                    child: const Text('Next'),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
