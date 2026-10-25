import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/features/dashboard/presentation/workspace_navigation.dart';
import 'package:hrflow_mobile/features/identity/domain/models.dart';

Profile _profile(String role) => Profile(
  id: role,
  tenantId: 'test',
  name: role,
  email: '$role@example.test',
  role: role,
);

void main() {
  test('each role has at most five tabs and the correct primary workspace', () {
    expect(workspaceTabs(_profile('EMPLOYEE')).map((tab) => tab.label), [
      'Home',
      'Activity',
      'Requests',
      'Leave',
      'Work',
    ]);
    expect(workspaceTabs(_profile('MANAGER')).map((tab) => tab.label), [
      'Home',
      'Activity',
      'Requests',
      'Approvals',
      'Work',
    ]);
    for (final role in ['HR_ADMIN', 'OWNER']) {
      expect(workspaceTabs(_profile(role)).map((tab) => tab.label), [
        'Home',
        'Activity',
        'Requests',
        'Approvals',
        'Work',
      ]);
    }
  });

  testWidgets('manager navigation remains operable at 360px and 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: WorkspaceNavigation(
            profile: _profile('MANAGER'),
            location: '/approvals',
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('Approvals'), findsOneWidget);
  });
}
