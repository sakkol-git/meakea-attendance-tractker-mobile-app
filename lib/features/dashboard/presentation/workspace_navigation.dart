import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hrflow_mobile/features/identity/domain/models.dart';

class WorkspaceTab {
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const WorkspaceTab(this.path, this.label, this.icon, this.selectedIcon);
}

const _home = WorkspaceTab(
  '/home',
  'Home',
  Icons.grid_view_outlined,
  Icons.grid_view_rounded,
);
const _activity = WorkspaceTab(
  '/activity',
  'Activity',
  Icons.schedule_outlined,
  Icons.schedule,
);
const _requests = WorkspaceTab(
  '/requests',
  'Requests',
  Icons.assignment_outlined,
  Icons.assignment,
);
const _leave = WorkspaceTab('/leave', 'Leave', Icons.spa_outlined, Icons.spa);
const _approvals = WorkspaceTab(
  '/approvals',
  'Approvals',
  Icons.fact_check_outlined,
  Icons.fact_check,
);
const _work = WorkspaceTab(
  '/workflows',
  'Work',
  Icons.work_outline,
  Icons.work,
);
const _profile = WorkspaceTab(
  '/profile',
  'Profile',
  Icons.person_outline,
  Icons.person,
);

List<WorkspaceTab> workspaceTabs(Profile profile) => [
  _home,
  _activity,
  if (profile.administers) _work else _requests,
  if (profile.manages) _approvals else _leave,
  _profile,
];

class WorkspaceNavigation extends StatelessWidget {
  final Profile profile;
  final String location;
  const WorkspaceNavigation({
    super.key,
    required this.profile,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = workspaceTabs(profile);
    return NavigationBar(
      selectedIndex: tabs
          .indexWhere((tab) => tab.path == location)
          .clamp(0, tabs.length - 1),
      onDestinationSelected: (index) => context.go(tabs[index].path),
      destinations: [
        for (final tab in tabs)
          NavigationDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.selectedIcon),
            label: tab.label,
          ),
      ],
    );
  }
}
