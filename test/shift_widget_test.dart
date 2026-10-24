import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/app.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';

import 'support/workspace_fixture.dart';

import 'package:hrflow_mobile/core/data/storage.dart';

class TestAppearance extends SettingsController {
  @override
  Settings build() => const Settings();
}

void main() {
  testWidgets(
    'HR assigns a dated shift at 200% text; employee sees the schedule and cannot open HR editor',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final client = await ClientData.create(
        secrets: MemorySecrets(),
        persistDemo: false,
      );
      final container = ProviderContainer(
        overrides: [
          clientProvider.overrideWithValue(client),
          ...testRepositoryOverrides(HrRepository(client)),
          settingsProvider.overrideWith(TestAppearance.new),
          clockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 23, 3)),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(client.close);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HrFlowApp(),
        ),
      );
      await tester.pumpAndSettle();
      await container.read(sessionProvider.notifier).demo('HR_ADMIN');
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/directory');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sok Dara'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Manage shift assignments'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Manage shift assignments'));
      await tester.pumpAndSettle();
      expect(find.text('Shift assignments'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Assign a work shift'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Assign a work shift'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '2026-10-26');
      await tester.ensureVisible(find.text('No end date'));
      await tester.tap(find.text('No end date'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextFormField).last);
      await tester.enterText(find.byType(TextFormField).last, '2026-10-30');
      await tester.tap(find.text('Assign shift'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.scrollUntilVisible(
        find.text('26 Oct 2026'),
        -250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('26 Oct 2026'), findsOneWidget);
      expect(find.text('30 Oct 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await container.read(sessionProvider.notifier).demo('EMPLOYEE');
      container.read(routerProvider).go('/schedule');
      await tester.pumpAndSettle();
      expect(find.text('26 Oct 2026'), findsOneWidget);
      expect(find.text('30 Oct 2026'), findsOneWidget);
      container.read(routerProvider).go('/people/demo-manager/shifts');
      await tester.pumpAndSettle();
      expect(find.text('Your workday'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
