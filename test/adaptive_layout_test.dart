import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/app.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/demo/local_service.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/features/settings/domain/preferences_gateway.dart';

import 'support/workspace_fixture.dart';

class MemoryPreferences implements PreferencesGateway {
  @override
  Future<bool?> read(String key) async => false;

  @override
  Future<void> write(String key, bool value) async {}
}

void main() {
  testWidgets('main workflows adapt to a tablet with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
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
        clientProvider.overrideWithValue(client),
        preferencesProvider.overrideWithValue(MemoryPreferences()),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 23, 10)),
        ...testRepositoryOverrides(HrRepository(client)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HrFlowApp()),
    );
    await tester.pumpAndSettle();
    await container.read(sessionProvider.notifier).demo('HR_ADMIN');

    for (final path in [
      '/home',
      '/activity',
      '/requests',
      '/leave',
      '/approvals',
      '/directory',
      '/manage/departments',
      '/reports',
      '/team-attendance',
      '/notifications',
      '/profile',
      '/workflows',
    ]) {
      container.read(routerProvider).go(path);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: path);
    }

    final correctionCard = find.ancestor(
      of: find.text('Request an attendance correction'),
      matching: find.byType(Card),
    );
    final leaveCard = find.ancestor(
      of: find.text('Leave requests and balances'),
      matching: find.byType(Card),
    );
    expect(correctionCard, findsOneWidget);
    expect(leaveCard, findsOneWidget);
    expect(
      tester.getTopLeft(leaveCard).dy - tester.getBottomLeft(correctionCard).dy,
      greaterThanOrEqualTo(8),
    );
  });

  testWidgets('request form stays scrollable above a phone keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
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
        clientProvider.overrideWithValue(client),
        preferencesProvider.overrideWithValue(MemoryPreferences()),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 23, 10)),
        ...testRepositoryOverrides(HrRepository(client)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HrFlowApp()),
    );
    await tester.pumpAndSettle();
    await container.read(sessionProvider.notifier).demo('EMPLOYEE');
    container.read(routerProvider).go('/new/request');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextFormField, 'What do you need?'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reason'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Reason'), findsOneWidget);
  });
}
