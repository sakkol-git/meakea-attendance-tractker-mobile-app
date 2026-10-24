import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hrflow_mobile/app.dart';
import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';

import 'support/workspace_fixture.dart';

import 'package:hrflow_mobile/core/data/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'company dates convert timestamps without shifting date-only values',
    () {
      expect(shortDate('2026-10-23T18:30:00Z'), '24 Oct 2026');
      expect(shortDate('2026-10-23'), '23 Oct 2026');
    },
  );

  testWidgets('employee demo signs in and navigates to leave and requests', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = await ClientData.create(
      secrets: MemorySecrets(),
      persistDemo: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clientProvider.overrideWithValue(client),
          ...testRepositoryOverrides(HrRepository(client)),
          settingsProvider.overrideWith(TestSettings.new),
        ],
        child: const HrFlowApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Employee'), findsOneWidget);
    await tester.tap(find.text('Employee'));
    await tester.pumpAndSettle();
    expect(find.text('Your workday'), findsOneWidget);
    expect(find.text('Clock in'), findsWidgets);
    await tester.tap(find.text('Leave').last);
    await tester.pumpAndSettle();
    expect(find.text('Time off'), findsOneWidget);
    expect(find.text('Annual leave'), findsWidgets);
    await tester.tap(find.text('Requests').last);
    await tester.pumpAndSettle();
    expect(find.text('Workspace upgrade'), findsOneWidget);
    await tester.tap(find.byTooltip('New request'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Workflow navigation check',
    );
    await tester.enterText(
      find.byType(TextFormField).last,
      'Validate draft submission and safe return navigation.',
    );
    await tester.tap(find.text('Save request draft'));
    await tester.pumpAndSettle();
    expect(find.text('Workflow navigation check'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    await tester.ensureVisible(find.text('Submit request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit request'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Pending approval'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Requests'), findsWidgets);
    expect(find.text('Workflow navigation check'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class TestSettings extends SettingsController {
  @override
  Settings build() => const Settings();
}
