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
List<WorkspaceTab> workspaceTabs(Profile profile) => [
  _home,
  _activity,
  _requests,
  if (profile.manages || profile.administers) _approvals else _leave,
  _work,
];

class WorkspaceNavigation extends StatelessWidget {
  final Profile profile;
  final String location;
  const WorkspaceNavigation({
    super.key,
    required this.profile,
    required this.location,
  });

  int _selectedIndex(List<WorkspaceTab> tabs) {
    final direct = tabs.indexWhere((tab) => tab.path == location);
    if (direct >= 0) return direct;
    if (location.startsWith('/profile')) {
      final workIndex = tabs.indexWhere((tab) => tab.path == '/workflows');
      if (workIndex >= 0) return workIndex;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = workspaceTabs(profile);
    final compactLabels =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(12) > 16;
    return NavigationBar(
      labelBehavior: compactLabels
          ? NavigationDestinationLabelBehavior.onlyShowSelected
          : NavigationDestinationLabelBehavior.alwaysShow,
      selectedIndex: _selectedIndex(tabs),
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
