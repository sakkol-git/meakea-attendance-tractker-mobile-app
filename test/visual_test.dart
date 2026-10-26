import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/app.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/core/demo/local_service.dart';
import 'package:hrflow_mobile/core/protocol.dart';

import 'support/workspace_fixture.dart';

import 'package:hrflow_mobile/core/data/storage.dart';

class VisualSettings extends SettingsController {
  final bool dark;
  VisualSettings({this.dark = false});
  @override
  Settings build() => Settings(dark: dark);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('KantumruyPro')
      ..addFont(rootBundle.load('assets/fonts/KantumruyPro[wght].ttf'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final scenario in [
    ('home', '/home', 'EMPLOYEE'),
    ('manager-home', '/home', 'MANAGER'),
    ('hr-home', '/home', 'HR_ADMIN'),
    ('owner-home', '/home', 'OWNER'),
    ('leave', '/leave', 'EMPLOYEE'),
    ('request', '/record/request/request-draft', 'EMPLOYEE'),
    ('approvals', '/approvals', 'MANAGER'),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'render ${dark ? 'dark ' : ''}${scenario.$1} mobile reference',
        (tester) async {
          tester.view.physicalSize = const Size(402, 874);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final client = visualClient();
          final container = ProviderContainer(
            overrides: [
              clientProvider.overrideWithValue(client),
              clockProvider.overrideWithValue(() => DateTime(2026, 10, 23, 10)),
              ...testRepositoryOverrides(HrRepository(client)),
              settingsProvider.overrideWith(() => VisualSettings(dark: dark)),
            ],
          );
          addTearDown(container.dispose);
          const key = Key('screen');
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const RepaintBoundary(key: key, child: HrFlowApp()),
            ),
          );
          await tester.pumpAndSettle();
          await container.read(sessionProvider.notifier).demo(scenario.$3);
          await tester.pumpAndSettle();
          container.read(routerProvider).go(scenario.$2);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(key),
            matchesGoldenFile(
              'goldens/${dark ? 'dark-' : ''}${scenario.$1}.png',
            ),
          );
        },
      );
    }
  }
  testWidgets(
    'all employee and HR routes render at 360px with 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final client = visualClient();
      final container = ProviderContainer(
        overrides: [
          clientProvider.overrideWithValue(client),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 23, 10)),
          ...testRepositoryOverrides(HrRepository(client)),
          settingsProvider.overrideWith(VisualSettings.new),
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
      await container.read(sessionProvider.notifier).demo('EMPLOYEE');
      for (final path in [
        '/home',
        '/activity',
        '/requests',
        '/leave',
        '/profile',
        '/new/leave',
        '/new/request',
        '/new/correction',
        '/notifications',
        '/schedule',
        '/profile/edit',
        '/security',
        '/preferences',
        '/about',
        '/record/request/request-draft',
      ]) {
        container.read(routerProvider).go(path);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: path);
      }
      await container.read(sessionProvider.notifier).demo('HR_ADMIN');
      for (final path in [
        '/approvals',
        '/directory',
        '/people/demo-employee/shifts',
        '/reports',
        '/team-attendance',
        '/manage/departments',
        '/manage/positions',
        '/manage/shifts',
        '/manage/holidays',
        '/manage/leave-types',
        '/manage/materials',
        '/audit',
      ]) {
        container.read(routerProvider).go(path);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: path);
      }
    },
  );
  testWidgets('dark appearance renders core routes without errors', (
    tester,
  ) async {
    final client = await ClientData.create(
      secrets: MemorySecrets(),
      persistDemo: false,
    );
    final container = ProviderContainer(
      overrides: [
        clientProvider.overrideWithValue(client),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 23, 10)),
        ...testRepositoryOverrides(HrRepository(client)),
        settingsProvider.overrideWith(() => VisualSettings(dark: true)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const HrFlowApp()),
    );
    await tester.pumpAndSettle();
    await container.read(sessionProvider.notifier).demo('EMPLOYEE');
    for (final path in ['/home', '/leave', '/requests', '/profile']) {
      container.read(routerProvider).go(path);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: path);
    }
  });
}

ClientData visualClient() => ClientData.forTest(
  LocalDataSource(
    jsonDecode(File('assets/data/demo-seed.json').readAsStringSync())
        as JsonMap,
    populate: true,
    now: () => DateTime.utc(2026, 10, 23, 3),
  ),
  store: MemorySecrets(),
);
