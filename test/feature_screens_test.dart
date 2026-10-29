import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/app.dart';
import 'package:hrflow_mobile/app/composition.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/app/feature_panels.dart';
import 'package:hrflow_mobile/core/demo/local_service.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/features/settings/domain/preferences_gateway.dart';

class MemoryPreferences implements PreferencesGateway {
  @override
  Future<bool?> read(String key) async => false;
  @override
  Future<void> write(String key, bool value) async {}
}

void main() {
  testWidgets(
    'production feature composition renders every workflow and editor at 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final source = LocalDataSource(
        jsonDecode(File('assets/data/demo-seed.json').readAsStringSync())
            as JsonMap,
        populate: true,
        now: () => DateTime.utc(2026, 10, 23, 3),
      );
      final client = ClientData.forTest(source);
      final container = ProviderContainer(
        overrides: [
          ...composeFeatures(client, preferences: MemoryPreferences()),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 23, 10)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HrFlowApp(),
        ),
      );
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/setup');
      await tester.pumpAndSettle();
      expect(find.text('Company name'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await container.read(sessionProvider.notifier).demo('OWNER');
      for (final panel in featurePanels) {
        container.read(routerProvider).go('/features/${panel.key}');
        await tester.pumpAndSettle();
        expect(find.text(panel.title), findsWidgets, reason: panel.key);
        expect(
          find.text('Something went wrong'),
          findsNothing,
          reason: panel.key,
        );
        expect(find.text('Try again'), findsNothing, reason: panel.key);
        expect(tester.takeException(), isNull, reason: panel.key);
        for (final action in panel.actions) {
          final buttons = find.text(action.label);
          if (buttons.evaluate().isEmpty) continue;
          await tester.ensureVisible(buttons.first);
          await tester.pumpAndSettle();
          await tester.tap(buttons.first);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${panel.key} ${action.key}',
          );
          await tester.tap(find.text('Go back'));
          await tester.pumpAndSettle();
        }
        if (panel.create != null &&
            (panel.create!.when?.call(
                  null,
                  container.read(sessionProvider).profile!,
                ) ??
                true)) {
          await tester.drag(
            find.byType(ListView).first,
            const Offset(0, 10000),
          );
          await tester.pumpAndSettle();
          final button = find.text(panel.create!.label);
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${panel.key} editor');
          await tester.tap(find.text('Go back'));
          await tester.pumpAndSettle();
        }
      }
      container.read(routerProvider).go('/evidence/capture');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Capture location'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Capture location'));
      await tester.pumpAndSettle();
      expect(find.text('Submit observation'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await container.read(sessionProvider.notifier).demo('EMPLOYEE');
      container.read(routerProvider).go('/features/leave.balances');
      await tester.pumpAndSettle();
      expect(find.text('Tasks'), findsWidgets);
      expect(find.text('Adjust entitlement'), findsNothing);
      await container.read(sessionProvider.notifier).demo('OWNER');
      container.read(routerProvider).go('/workflows');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search tasks'),
        'Report recovery',
      );
      await tester.pumpAndSettle();
      tester.testTextInput.hide();
      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Report recovery'), findsNothing);
    },
  );
}
