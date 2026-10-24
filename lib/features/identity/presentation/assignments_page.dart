import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/features/identity/application/shift_use_cases.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/features/identity/domain/models.dart';

class ShiftAssignmentsPage extends ConsumerWidget {
  final String employeeId;
  final String? employeeName;
  const ShiftAssignmentsPage(this.employeeId, {this.employeeName, super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAssign = ref.watch(sessionProvider).profile!.administers;
    return AppPage(
      title: 'Shift assignments',
      subtitle: employeeName == null
          ? 'Effective work schedules for this employee.'
          : 'Work schedules for $employeeName.',
      onRefresh: () async {
        ref.invalidate(shiftAssignmentsProvider(employeeId));
        await ref.read(shiftAssignmentsProvider(employeeId).future);
      },
      children: [
        ShiftAssignmentsSection(employeeId),
        if (canAssign) ...[
          const SizedBox(height: 24),
          AsyncPanel(
            value: ref.watch(shiftOptionsProvider),
            retry: () => ref.invalidate(shiftOptionsProvider),
            builder: (shifts) => shifts.isEmpty
                ? const EmptyState(
                    title: 'Create a work shift first',
                    description: 'Add a shift under Profile → Shift rules before assigning it to an employee.',
                  )
                : FilledButton.icon(
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Assign a work shift'),
                    onPressed: () =>
                        assignShiftDialog(context, ref, employeeId, shifts),
                  ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Date ranges include both the first and last day. Existing assignments are preserved. An overlapping period must be resolved before adding another assignment.',
            style: TextStyle(color: Palette.muted),
          ),
        ],
      ],
    );
  }
}

class ShiftAssignmentsSection extends ConsumerWidget {
  final String employeeId;
  const ShiftAssignmentsSection(this.employeeId, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref
        .watch(clockProvider)()
        .toUtc()
        .add(const Duration(hours: 7))
        .toIso8601String()
        .substring(0, 10);
    return AsyncPanel(
      value: ref.watch(shiftAssignmentsProvider(employeeId)),
      retry: () => ref.invalidate(shiftAssignmentsProvider(employeeId)),
      builder: (rows) => rows.isEmpty
          ? const EmptyState(
              title: 'No assigned shifts',
              description: 'HR can assign a work schedule. Company shift rules are reference information; they do not establish a personal assignment.',
              icon: Icons.event_note_outlined,
            )
          : Column(
              children: [
                for (final assignment in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assignment.shiftName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            assignment.includes(date)
                                ? 'Current assignment'
                                : assignment.validFrom.compareTo(date) > 0
                                ? 'Upcoming assignment'
                                : 'Previous assignment',
                            style: const TextStyle(
                              color: Palette.teal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          InfoRow('First day', shortDate(assignment.validFrom)),
                          InfoRow(
                            'Last day',
                            assignment.validTo == null
                                ? 'No end date'
                                : shortDate(assignment.validTo),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

Future<void> assignShiftDialog(
  BuildContext context,
  WidgetRef ref,
  String employeeId,
  List<ShiftOption> shifts,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _AssignShiftDialog(employeeId, shifts),
);

class _AssignShiftDialog extends ConsumerStatefulWidget {
  final String employeeId;
  final List<ShiftOption> shifts;
  const _AssignShiftDialog(this.employeeId, this.shifts);
  @override
  ConsumerState<_AssignShiftDialog> createState() => _AssignShiftState();
}

class _AssignShiftState extends ConsumerState<_AssignShiftDialog> {
  final form = GlobalKey<FormState>();
  late final DateTime now;
  late final TextEditingController from, to;
  late String shift;
  bool noEnd = true, busy = false;
  String? error, previous;
  String key = commandKey();
  @override
  void initState() {
    super.initState();
    now = ref.read(clockProvider)().toUtc().add(const Duration(hours: 7));
    from = TextEditingController(text: now.toIso8601String().substring(0, 10));
    to = TextEditingController(text: now.toIso8601String().substring(0, 10));
    shift = widget.shifts.first.id;
  }

  @override
  void dispose() {
    from.dispose();
    to.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dialog = context,
        employeeId = widget.employeeId,
        shifts = widget.shifts;
    void update(VoidCallback task) => setState(task);
    Future<void> pick(TextEditingController field) async {
      final parsed = DateTime.tryParse(field.text);
      final selected = await showDatePicker(
        context: dialog,
        initialDate:
            parsed != null && parsed.year >= 2000 && parsed.year <= 2100
            ? parsed
            : DateTime(now.year, now.month, now.day),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100, 12, 31),
      );
      if (selected != null && dialog.mounted) {
        update(() => field.text = selected.toIso8601String().substring(0, 10));
      }
    }

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: const Text('Assign a work shift'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: shift,
                    isExpanded: true,
                    itemHeight: null,
                    decoration: const InputDecoration(labelText: 'Work shift'),
                    items: shifts
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              '${item.name} · ${item.startTime}–${item.endTime}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: busy
                        ? null
                        : (value) => update(() => shift = value!),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: from,
                    enabled: !busy,
                    decoration: InputDecoration(
                      labelText: 'First day',
                      hintText: 'YYYY-MM-DD',
                      suffixIcon: IconButton(
                        tooltip: 'Choose first day',
                        onPressed: busy ? null : () => pick(from),
                        icon: const Icon(Icons.calendar_today_outlined),
                      ),
                    ),
                    validator: (value) =>
                        ShiftUseCases.validDate(value?.trim() ?? '')
                        ? null
                        : 'Enter a valid date as YYYY-MM-DD',
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('No end date'),
                    value: noEnd,
                    onChanged: busy
                        ? null
                        : (value) => update(() => noEnd = value),
                  ),
                  if (!noEnd)
                    TextFormField(
                      controller: to,
                      enabled: !busy,
                      decoration: InputDecoration(
                        labelText: 'Last day',
                        hintText: 'YYYY-MM-DD',
                        suffixIcon: IconButton(
                          tooltip: 'Choose last day',
                          onPressed: busy ? null : () => pick(to),
                          icon: const Icon(Icons.calendar_today_outlined),
                        ),
                      ),
                      validator: (value) =>
                          !ShiftUseCases.validDate(value?.trim() ?? '')
                          ? 'Enter a valid date as YYYY-MM-DD'
                          : value!.trim().compareTo(from.text.trim()) < 0
                          ? 'The last day must follow the first day'
                          : null,
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
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
            onPressed: busy ? null : () => Navigator.pop(dialog),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    final first = from.text.trim(),
                        last = noEnd ? null : to.text.trim();
                    final fingerprint = canonicalJson({
                      'shiftId': shift,
                      'validFrom': first,
                      'validTo': last,
                    });
                    if (fingerprint != previous) {
                      key = commandKey();
                      previous = fingerprint;
                    }
                    update(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      await ref
                          .read(shiftUseCasesProvider)
                          .assign(
                            ref.read(sessionProvider).profile!,
                            employeeId,
                            shift,
                            first,
                            last,
                            key,
                          );
                      if (!dialog.mounted) return;
                      ref.invalidate(shiftAssignmentsProvider(employeeId));
                      ref.invalidate(todayProvider);
                      ref.invalidate(collectionProvider('/audit-logs'));
                      Navigator.pop(dialog);
                      if (context.mounted) {
                        toast(context, 'Work shift assigned');
                      }
                    } catch (failure) {
                      if (dialog.mounted) {
                        update(() => error = message(failure));
                      }
                    } finally {
                      if (dialog.mounted) update(() => busy = false);
                    }
                  },
            child: Text(busy ? 'Assigning…' : 'Assign shift'),
          ),
        ],
      ),
    );
  }
}
