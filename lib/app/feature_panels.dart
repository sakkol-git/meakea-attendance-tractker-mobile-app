import '../features/operations/presentation/case_pages.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets.dart';

import 'package:hrflow_mobile/features/identity/domain/models.dart';

import '../shared/presentation/case_page.dart';
import '../features/identity/presentation/case_pages.dart';
import '../features/attendance/presentation/case_pages.dart';
import '../features/leave/presentation/case_pages.dart';
import '../features/requests/presentation/case_pages.dart';
import '../features/notifications/presentation/case_pages.dart';
import '../features/reporting/presentation/case_pages.dart';
import 'providers.dart';

const featurePanels = [
  ...operationsPanels,
  ...identityPanels,
  ...attendancePanels,
  ...leavePanels,
  ...requestsPanels,
  ...notificationsPanels,
  ...reportingPanels,
];
bool canOpenPanel(CasePanel panel, Profile p) => switch (panel.access) {
  'employee' => true,
  'manager' => p.manages,
  'owner' => p.role == 'OWNER',
  _ => p.administers,
};
CasePanel? panelFor(String key) =>
    featurePanels.where((p) => p.key == key).firstOrNull;

class WorkflowHub extends ConsumerWidget {
  const WorkflowHub({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = ref.watch(sessionProvider).profile!;
    final query = ref.watch(taskSearchProvider).trim().toLowerCase();
    final account = '${actor.tenantId}:${actor.id}';
    final recent = ref.watch(recentTasksProvider(account));
    bool matches(String title) => title.toLowerCase().contains(query);
    bool canOpenRecent(String path) {
      if (!path.startsWith('/features/')) return true;
      final panel = panelFor(path.substring('/features/'.length));
      return panel != null && canOpenPanel(panel, actor);
    }

    void open(String title, String path) {
      final current = ref.read(recentTasksProvider(account));
      ref.read(recentTasksProvider(account).notifier).state = [
        (title: title, path: path),
        ...current.where((item) => item.path != path),
      ].take(4).toList();
      context.push(path);
    }

    const groups = {
      'operations': 'Service readiness',
      'identity': 'People & organization',
      'attendance': 'Attendance',
      'leave': 'Leave & accounting',
      'requests': 'Requests & materials',
      'notifications': 'Notifications',
      'reporting': 'Reports & recovery',
    };
    return AppPage(
      title: 'All workflows',
      subtitle: 'Find an authorized task by name or feature.',
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search tasks',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) =>
              ref.read(taskSearchProvider.notifier).state = value,
        ),
        if (query.isEmpty && recent.isNotEmpty) ...[
          const SectionTitle('Recently used'),
          for (final task in recent)
            if (canOpenRecent(task.path))
              Card(
                child: ListTile(
                  title: Text(task.title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(task.title, task.path),
                ),
              ),
        ],
        if (query.isEmpty) const SectionTitle('Daily work'),
        for (final item in [
          ('Clock in or out', '/home'),
          ('Attendance and inferred reviews', '/activity'),
          ('Request an attendance correction', '/new/correction'),
          ('Leave requests and balances', '/leave'),
          ('General and material requests', '/requests'),
          ('My schedule', '/schedule'),
          ('Inbox', '/notifications'),
        ])
          if (matches(item.$1))
            Card(
              child: ListTile(
                title: Text(item.$1),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(item.$1, item.$2),
              ),
            ),
        if (actor.manages && matches('Approval queue'))
          Card(
            child: ListTile(
              title: const Text('Approval queue'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open('Approval queue', '/approvals'),
            ),
          ),
        if (actor.administers && matches('Assign employee shifts'))
          Card(
            child: ListTile(
              title: const Text('Assign employee shifts'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open('Assign employee shifts', '/directory'),
            ),
          ),
        for (final group in groups.entries) ...[
          if (featurePanels.any(
            (p) =>
                p.key.startsWith('${group.key}.') &&
                canOpenPanel(p, actor) &&
                (matches(p.title) ||
                    matches(p.description) ||
                    matches(group.value)),
          ))
            SectionTitle(group.value),
          for (final panel in featurePanels.where(
            (p) =>
                p.key.startsWith('${group.key}.') &&
                canOpenPanel(p, actor) &&
                (matches(p.title) ||
                    matches(p.description) ||
                    matches(group.value)),
          ))
            Card(
              child: ListTile(
                title: Text(panel.title),
                subtitle: Text(panel.description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(panel.title, '/features/${panel.key}'),
              ),
            ),
        ],
      ],
    );
  }
}

final taskSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final recentTasksProvider =
    StateProvider.family<List<({String title, String path})>, String>(
      (ref, account) => [],
    );
