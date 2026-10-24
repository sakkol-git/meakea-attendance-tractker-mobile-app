import 'package:flutter/material.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/app/cases.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/shared/domain/cases.dart';
import 'package:hrflow_mobile/shared/presentation/case_page.dart';

import 'case_pages.dart';

const adminPaths = {
  'departments': '/departments',
  'positions': '/positions',
  'shifts': '/shifts',
  'holidays': '/holidays',
  'leave-types': '/leave/types',
  'materials': '/materials',
};
const adminNames = {
  'departments': 'Departments',
  'positions': 'Positions',
  'shifts': 'Shift rules',
  'holidays': 'Company holidays',
  'leave-types': 'Leave types',
  'materials': 'Materials catalog',
};

class DirectoryPage extends ConsumerStatefulWidget {
  const DirectoryPage({super.key});
  @override
  ConsumerState<DirectoryPage> createState() => _DirectoryState();
}

class _DirectoryState extends ConsumerState<DirectoryPage> {
  String search = '';
  Timer? searchDebounce;
  @override
  void dispose() {
    searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(sessionProvider).profile!.administers;
    final provider = caseRowsProvider((
      collection: 'identity.people',
      search: search,
      from: '',
      to: '',
    ));
    return AppPage(
      title: 'People directory',
      subtitle: 'Good work starts with people.',
      actions: admin
          ? [
              IconButton(
                tooltip: 'Add employee',
                onPressed: () =>
                    editEntity(context, ref, '/employees', 'employee'),
                icon: Icon(Icons.person_add_alt),
              ),
            ]
          : null,
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'Search people or departments',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) {
            searchDebounce?.cancel();
            searchDebounce = Timer(const Duration(milliseconds: 300), () {
              if (mounted) setState(() => search = v.trim());
            });
          },
        ),
        const SizedBox(height: 20),
        AsyncPanel(
          value: ref.watch(provider),
          retry: () => ref.invalidate(provider),
          builder: (people) {
            if (people.isEmpty) {
              return const EmptyState(
                title: 'No matches',
                description: 'Try a different name or department.',
                icon: Icons.people_outline,
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${people.length} shown'),
                ),
                ...people.map((record) {
                  final p = record.values;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: context.semantic.successBackground,
                          child: Text(
                            ('${(p['name'] as String? ?? p['fullName'] as String? ?? '').trim()}?')
                                .substring(0, 1),
                          ),
                        ),
                        title: Text(
                          p['name'] as String? ??
                              p['fullName'] as String? ??
                              'Employee',
                        ),
                        subtitle: Text(
                          '${p['position'] ?? ''} · ${p['department'] ?? ''}',
                        ),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () => showPerson(context, p, admin),
                      ),
                    ),
                  );
                }),
                if (ref.read(provider.notifier).more)
                  BusyButton(
                    label: 'Load more people',
                    action: () => ref.read(provider.notifier).loadMore(),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  void showPerson(BuildContext context, JsonMap person, bool admin) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                person['name'] as String? ??
                    person['fullName'] as String? ??
                    'Employee',
                style: Theme.of(c).textTheme.titleLarge,
              ),
              InfoRow('Email', person['email'] as String? ?? '—'),
              InfoRow('Department', person['department'] as String? ?? '—'),
              InfoRow('Position', person['position'] as String? ?? '—'),
              if (admin)
                OutlinedButton.icon(
                  icon: Icon(Icons.event_available_outlined),
                  onPressed: () {
                    Navigator.pop(c);
                    context.push(
                      '/people/${person['id']}/shifts',
                      extra:
                          person['name'] as String? ??
                          person['fullName'] as String?,
                    );
                  },
                  label: Text('Manage shift assignments'),
                ),
              if (admin)
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(c);
                    editEntity(
                      context,
                      ref,
                      '/employees',
                      'employee',
                      existing: person,
                    );
                  },
                  child: Text('Edit employee'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminListPage extends ConsumerWidget {
  final String kind;
  const AdminListPage(this.kind, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = adminPaths[kind]!, title = adminNames[kind]!;
    return AppPage(
      title: title,
      actions: [
        IconButton(
          tooltip: 'Add record',
          onPressed: () => editEntity(context, ref, path, title),
          icon: Icon(Icons.add),
        ),
      ],
      children: [
        AsyncPanel(
          value: ref.watch(collectionProvider(path)),
          retry: () => ref.invalidate(collectionProvider(path)),
          builder: (rows) => rows.isEmpty
              ? EmptyState(
                  title: 'No records yet',
                  description: 'Add the first record to get started.',
                  action: TextButton(
                    onPressed: () => editEntity(context, ref, path, title),
                    child: Text('Add record'),
                  ),
                )
              : Column(
                  children: [
                    for (final r in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            title: Text(
                              r['name'] as String? ?? 'Record',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              kind == 'holidays'
                                  ? shortDate(r['date'] as String?)
                                  : kind == 'shifts'
                                  ? '${r['startTime']} – ${r['endTime']}'
                                  : kind == 'leave-types'
                                  ? '${r['entitled'] ?? 'Policy-defined'} days'
                                  : 'Organization record',
                            ),
                            trailing: Icon(Icons.edit_outlined, size: 20),
                            onTap: () => editEntity(
                              context,
                              ref,
                              path,
                              title,
                              existing: r,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

Future<void> editEntity(
  BuildContext context,
  WidgetRef ref,
  String path,
  String title, {
  JsonMap? existing,
}) async {
  final typedPanelKey = switch (path) {
    '/employees' => 'identity.people',
    '/departments' => 'identity.departments',
    '/positions' => 'identity.positions',
    '/shifts' => 'identity.shifts',
    _ => null,
  };
  if (typedPanelKey != null) {
    final panel = identityPanels.firstWhere((p) => p.key == typedPanelKey);
    final action = existing == null
        ? panel.create!
        : panel.actions.firstWhere((a) => a.key.endsWith('.edit'));
    final record = existing == null
        ? null
        : CaseRecord(
            id: existing['id'] as String,
            title: (existing['name'] ?? title).toString(),
            status: (existing['status'] ?? 'ACTIVE').toString(),
            version: existing['version'] as int,
            revision: existing['etag'] as String?,
            values: existing,
          );
    await showCaseEditor(context, ref, action, record);
    return;
  }
  final fields = <String, String>{
    'name': 'Name',
    if (path == '/holidays') 'date': 'Date (YYYY-MM-DD)',
    if (path == '/leave/types') 'entitled': 'Annual entitlement (days)',
    if (path == '/materials') 'unit': 'Unit',
  };
  final controllers = {
    for (final k in fields.keys)
      k: TextEditingController(text: existing?[k]?.toString() ?? ''),
  };
  final form = GlobalKey<FormState>();
  bool busy = false, dirty = false;
  String? error;
  var key = commandKey();
  String? previousPayload;
  Future<bool> discard(BuildContext dialog) async {
    if (!dirty) return true;
    return await showDialog<bool>(
          context: dialog,
          builder: (confirmation) => AlertDialog(
            title: Text(
              'Discard ${existing == null ? 'new' : 'edited'} $title?',
            ),
            content: const Text(
              'Your unsaved changes in this form will be lost.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(confirmation, false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(confirmation, true),
                child: const Text('Discard changes'),
              ),
            ],
          ),
        ) ??
        false;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => StatefulBuilder(
      builder: (c, setDialog) => PopScope(
        canPop: !busy && !dirty,
        onPopInvokedWithResult: (didPop, _) async {
          if (!didPop && !busy && await discard(c) && c.mounted) {
            dirty = false;
            Navigator.pop(c);
          }
        },
        child: AlertDialog(
          title: Text('${existing == null ? 'Add' : 'Edit'} $title'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: form,
              onChanged: () => dirty = true,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in fields.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          controller: controllers[entry.key],
                          decoration: InputDecoration(labelText: entry.value),
                          keyboardType: entry.key == 'entitled'
                              ? TextInputType.number
                              : entry.key == 'email'
                              ? TextInputType.emailAddress
                              : TextInputType.text,
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty && entry.key != 'managerId') {
                              return 'This field is required';
                            }
                            if (entry.key == 'email' && !value.contains('@')) {
                              return 'Enter a valid email';
                            }
                            if (entry.key == 'date' &&
                                DateTime.tryParse(value) == null) {
                              return 'Use YYYY-MM-DD';
                            }
                            if (entry.key == 'entitled' &&
                                (double.tryParse(value) == null ||
                                    double.parse(value) < 0)) {
                              return 'Enter a positive amount';
                            }
                            if (['startTime', 'endTime'].contains(entry.key) &&
                                !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$')
                                    .hasMatch(value)) {
                              return 'Use HH:mm';
                            }
                            return null;
                          },
                        ),
                      ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(color: context.semantic.error),
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
                      if (await discard(c) && c.mounted) {
                        dirty = false;
                        Navigator.pop(c);
                      }
                    },
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setDialog(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        final values = <String, dynamic>{
                          for (final e in controllers.entries)
                            e.key: e.key == 'entitled'
                                ? double.parse(e.value.text)
                                : e.value.text.trim(),
                        };
                        final payload = canonicalJson(values);
                        if (previousPayload != payload) {
                          key = commandKey();
                          previousPayload = payload;
                        }
                        if (existing == null) {
                          await ref
                              .read(identityRepositoryProvider)
                              .command(path, body: values, key: key);
                        } else {
                          await ref
                              .read(identityRepositoryProvider)
                              .saveEntity(path, values, existing: existing);
                        }
                        ref.invalidate(collectionProvider(path));
                        if (c.mounted) Navigator.pop(c);
                        if (context.mounted) toast(context, 'Changes saved');
                      } catch (e) {
                        if (c.mounted) setDialog(() => error = message(e));
                      } finally {
                        if (c.mounted) setDialog(() => busy = false);
                      }
                    },
              child: Text(busy ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    ),
  );
  for (final c in controllers.values) {
    c.dispose();
  }
}
