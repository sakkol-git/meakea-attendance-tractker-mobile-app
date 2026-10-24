import 'features/notifications/application/push.dart';
import 'features/identity/presentation/setup_page.dart';
import 'features/attendance/presentation/evidence_page.dart';
import 'app/feature_panels.dart';
import 'shared/presentation/case_page.dart';

import 'package:hrflow_mobile/features/attendance/presentation/team_page.dart';
import 'package:hrflow_mobile/features/notifications/presentation/inbox_page.dart';
import 'package:hrflow_mobile/features/identity/presentation/schedule_page.dart';
import 'package:hrflow_mobile/features/settings/presentation/settings_pages.dart';
import 'package:hrflow_mobile/features/reporting/presentation/reports_page.dart';
import 'package:hrflow_mobile/features/identity/presentation/audit_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/features/identity/presentation/auth_page.dart';
import 'package:hrflow_mobile/features/dashboard/presentation/home_page.dart';
import 'package:hrflow_mobile/features/dashboard/presentation/workspace_navigation.dart';
import 'package:hrflow_mobile/features/attendance/presentation/activity_page.dart';
import 'package:hrflow_mobile/features/workflows/presentation/form_page.dart';
import 'package:hrflow_mobile/features/workflows/presentation/workflow_pages.dart';
import 'package:hrflow_mobile/features/workflows/presentation/approval_position.dart';
import 'package:hrflow_mobile/features/approvals/presentation/delegations_page.dart';
import 'package:hrflow_mobile/features/identity/presentation/profile_page.dart';
import 'package:hrflow_mobile/features/identity/presentation/people_pages.dart';
import 'package:hrflow_mobile/features/identity/presentation/assignments_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.uri.path;
      if (session.loading) return location == '/startup' ? null : '/startup';
      if (session.profile == null) {
        return ['/login', '/setup'].contains(location) ? null : '/login';
      }
      if (session.locked) return location == '/lock' ? null : '/lock';
      if (['/login', '/startup', '/lock'].contains(location)) return '/home';
      if ([
            '/approvals',
            '/approvals/delegations',
            '/directory',
            '/reports',
            '/team-attendance',
          ].contains(location) &&
          !session.profile!.manages) {
        return '/home';
      }
      if ((location.startsWith('/manage/') ||
              location.startsWith('/people/') ||
              location == '/audit') &&
          !session.profile!.administers) {
        return '/home';
      }
      if (location.startsWith('/features/')) {
        final panel = panelFor(
          state.pathParameters['key'] ?? location.split('/').last,
        );
        if (panel == null || !canOpenPanel(panel, session.profile!)) {
          return '/workflows';
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/startup',
        builder: (_, _) => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Opening workspace',
            ),
          ),
        ),
      ),
      GoRoute(path: '/setup', builder: (_, _) => const WorkspaceSetupPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/lock', builder: (_, _) => const LockPage()),
      ShellRoute(
        builder: (context, state, child) =>
            WorkspaceShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomePage()),
          GoRoute(path: '/activity', builder: (_, _) => const ActivityPage()),
          GoRoute(
            path: '/requests',
            builder: (_, _) => const WorkflowListPage('request'),
          ),
          GoRoute(
            path: '/leave',
            builder: (_, _) => const WorkflowListPage('leave'),
          ),
          GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
          GoRoute(path: '/approvals', builder: (_, _) => const ApprovalPage()),
          GoRoute(path: '/workflows', builder: (_, _) => const WorkflowHub()),
        ],
      ),
      GoRoute(
        path: '/new/:kind',
        redirect: (_, s) =>
            [
              'leave',
              'request',
              'correction',
            ].contains(s.pathParameters['kind'])
            ? null
            : '/home',
        builder: (_, s) => RequestFormPage(s.pathParameters['kind']!),
      ),
      GoRoute(
        path: '/record/:kind/:id',
        redirect: (_, s) =>
            [
              'leave',
              'request',
              'correction',
            ].contains(s.pathParameters['kind'])
            ? null
            : '/home',
        builder: (_, s) => RecordDetailPage(
          s.pathParameters['kind']!,
          s.pathParameters['id']!,
          position: s.extra is ApprovalPosition
              ? s.extra as ApprovalPosition
              : null,
        ),
      ),
      GoRoute(
        path: '/team-attendance',
        builder: (_, _) => const TeamAttendancePage(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsPage(),
      ),
      GoRoute(path: '/schedule', builder: (_, _) => const SchedulePage()),
      GoRoute(
        path: '/approvals/delegations',
        builder: (_, _) => const DelegationsPage(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const EditProfilePage(),
      ),
      GoRoute(path: '/preferences', builder: (_, _) => const PreferencesPage()),
      GoRoute(path: '/security', builder: (_, _) => const SecurityPage()),
      GoRoute(
        path: '/security/password',
        builder: (_, _) => const PasswordPage(),
      ),
      GoRoute(path: '/about', builder: (_, _) => const AboutPage()),
      GoRoute(path: '/directory', builder: (_, _) => const DirectoryPage()),
      GoRoute(
        path: '/people/:id/shifts',
        builder: (_, state) => ShiftAssignmentsPage(
          state.pathParameters['id']!,
          employeeName: state.extra is String ? state.extra as String : null,
        ),
      ),
      GoRoute(
        path: '/evidence/capture',
        builder: (_, _) => const EvidenceCapturePage(),
      ),
      GoRoute(
        path: '/edit/request/:id',
        builder: (_, s) => EditRequestPage(s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/features/:key',
        builder: (_, s) => FeatureCasesPage(
          panelFor(s.pathParameters['key']!)!,
          key: ValueKey(s.pathParameters['key']),
        ),
      ),
      GoRoute(path: '/reports', builder: (_, _) => const ReportsPage()),
      GoRoute(path: '/audit', builder: (_, _) => const AuditPage()),
      GoRoute(
        path: '/manage/:kind',
        redirect: (_, s) =>
            adminPaths.containsKey(s.pathParameters['kind']) ? null : '/home',
        builder: (_, s) => AdminListPage(s.pathParameters['kind']!),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page unavailable')),
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/home'),
          child: const Text('Back to workspace'),
        ),
      ),
    ),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class HrFlowApp extends ConsumerStatefulWidget {
  const HrFlowApp({super.key});
  @override
  ConsumerState<HrFlowApp> createState() => _HrFlowAppState();
}

class _HrFlowAppState extends ConsumerState<HrFlowApp>
    with WidgetsBindingObserver {
  DateTime? backgrounded;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      backgrounded = DateTime.now();
    }
    if (state == AppLifecycleState.resumed) {
      final session = ref.read(sessionProvider);
      if (ref.read(settingsProvider).deviceLock &&
          session.profile != null &&
          !session.locked &&
          backgrounded != null &&
          DateTime.now().difference(backgrounded!) >
              const Duration(seconds: 30)) {
        ref.read(sessionProvider.notifier).lock();
      }
      backgrounded = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pushOpenedProvider, (_, value) {
      final data = value.asData?.value;
      final session = ref.read(sessionProvider);
      if (data == null || session.profile == null || session.locked) return;
      ref.invalidate(inboxProvider);
      final path = notificationRecordPath(data);
      if (path != null) ref.read(routerProvider).push(path);
    });
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: 'HRFlow',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      darkTheme: appTheme(dark: true),
      themeMode: settings.dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en')],
    );
  }
}

class WorkspaceShell extends ConsumerWidget {
  final String location;
  final Widget child;
  const WorkspaceShell({
    super.key,
    required this.location,
    required this.child,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = ref.watch(clientProvider).isLocal;
    return Scaffold(
      body: Column(
        children: [
          if (local)
            SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                color: context.semantic.successBackground,
                padding: const EdgeInsets.symmetric(
                  vertical: 5,
                  horizontal: 16,
                ),
                child: Text(
                  'DEMO WORKSPACE  ·  Fictional data',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.semantic.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (ref.watch(cacheStaleProvider).asData?.value == true)
            MaterialBanner(
              content: const Text('Showing saved data. It may be out of date.'),
              actions: [
                TextButton(
                  onPressed: () async {
                    await ref.read(clientProvider).clearCache();
                    ref.invalidate(todayProvider);
                    ref.invalidate(recordsProvider);
                    ref.invalidate(balancesProvider);
                  },
                  child: const Text('Refresh'),
                ),
              ],
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: WorkspaceNavigation(
        profile: ref.watch(sessionProvider).profile!,
        location: location,
      ),
    );
  }
}
