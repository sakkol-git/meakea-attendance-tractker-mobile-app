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
            icon: const Icon(Icons.date_range_outlined),
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
              icon: const Icon(Icons.my_location),
              label: const Text('Submit observation'),
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
              icon: const Icon(Icons.add),
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
                                    businessValue(row.values[detail.key]),
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
  final string = value.toString();
  return RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(string)
      ? shortDate(string)
      : statusLabel(string);
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
  bool busy = false, review = false;
  String? error, fingerprint;
  String key = commandKey(), commitKey = commandKey();
  Map<String, dynamic>? prepared;
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
      key = commandKey();
      fingerprint = hash;
      prepared = null;
      review = false;
      commitKey = commandKey();
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
        key: prepared == null ? key : commitKey,
        etag: widget.record?.etag,
      );
      if (!mounted) return;
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
      if (mounted) setState(() => error = message(failure));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(
          review ? 'Review ${action.label.toLowerCase()}' : action.label,
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: form,
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
                    if (prepared?['summary'] != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(prepared!['summary'].toString()),
                      ),
                    const Text(
                      'Confirm these changes. A reason and the resulting action are recorded where required.',
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
                        style: const TextStyle(color: Palette.danger),
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
                : () {
                    if (review) {
                      setState(() {
                        review = false;
                        prepared = null;
                      });
                    } else {
                      Navigator.pop(context);
                    }
                  },
            child: Text(review ? 'Revise' : 'Go back'),
          ),
          FilledButton(
            onPressed: busy ? null : submit,
            child: Text(
              busy
                  ? 'Saving…'
                  : review
                  ? 'Confirm'
                  : 'Review changes',
            ),
          ),
        ],
      ),
    );
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
    if (field.kind == FieldKind.lookup) {
      return ref
              .read(caseOptionsProvider(field.lookup!))
              .asData
              ?.value
              .where(
                (r) =>
                    (field.valueField == 'id'
                        ? r.id
                        : r.values[field.valueField]?.toString()) ==
                    value,
              )
              .firstOrNull
              ?.title ??
          'Selection unavailable — revise before confirming';
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
                style: const TextStyle(color: Palette.danger),
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
      return AsyncPanel(
        value: ref.watch(caseOptionsProvider(field.lookup!)),
        retry: () => ref.invalidate(caseOptionsProvider(field.lookup!)),
        builder: (rows) => choice(field, {
          for (final row in rows)
            (field.valueField == 'id'
                    ? row.id
                    : row.values[field.valueField].toString()):
                row.title,
        }),
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
        suffixIcon: field.kind == FieldKind.date
            ? IconButton(
                tooltip: 'Choose ${field.label.toLowerCase()}',
                onPressed: busy ? null : () => selectDate(field),
                icon: const Icon(Icons.calendar_today_outlined),
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
      decoration: InputDecoration(labelText: field.label),
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
