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
part 'master_editor.dart';

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
