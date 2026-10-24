import '../features/operations/presentation/case_pages.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      subtitle: 'Your available tasks, organized by feature.',
      children: [
        const SectionTitle('Daily work'),
        for (final item in [
          ('Clock in or out', '/home'),
          ('Attendance and inferred reviews', '/activity'),
          ('Request an attendance correction', '/new/correction'),
          ('Leave requests and balances', '/leave'),
          ('General and material requests', '/requests'),
          ('My schedule', '/schedule'),
          ('Inbox', '/notifications'),
        ])
          Card(
            child: ListTile(
              title: Text(item.$1),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(item.$2),
            ),
          ),
        if (actor.manages)
          Card(
            child: ListTile(
              title: const Text('Approval queue'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/approvals'),
            ),
          ),
        if (actor.administers)
          Card(
            child: ListTile(
              title: const Text('Assign employee shifts'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/directory'),
            ),
          ),
        for (final group in groups.entries) ...[
          if (featurePanels.any(
            (p) => p.key.startsWith('${group.key}.') && canOpenPanel(p, actor),
          ))
            SectionTitle(group.value),
          for (final panel in featurePanels.where(
            (p) => p.key.startsWith('${group.key}.') && canOpenPanel(p, actor),
          ))
            Card(
              child: ListTile(
                title: Text(panel.title),
                subtitle: Text(panel.description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/features/${panel.key}'),
              ),
            ),
        ],
      ],
    );
  }
}
