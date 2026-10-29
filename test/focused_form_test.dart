import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/app.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/data/storage.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';

import 'support/workspace_fixture.dart';

class FormSettings extends SettingsController {
  @override
  Settings build() => const Settings();
}

void main() {
  testWidgets(
    'request review follows edited values without submitting or losing fields',
    (tester) async {
      final client = await ClientData.create(
        secrets: MemorySecrets(),
        persistDemo: false,
      );
      final container = ProviderContainer(
        overrides: [
          clientProvider.overrideWithValue(client),
          ...testRepositoryOverrides(HrRepository(client)),
          settingsProvider.overrideWith(FormSettings.new),
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
      container.read(routerProvider).go('/new/request');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'A focused request',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'Please review this request for equipment.',
      );
      expect(find.text('Review details'), findsOneWidget);
      await tester.ensureVisible(find.text('Review details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review details'));
      await tester.pumpAndSettle();
      expect(
        find.text('Save a draft, then submit it from the request details.'),
        findsOneWidget,
      );
      expect(find.text('A focused request'), findsWidgets);
      await tester.ensureVisible(find.byType(TextFormField).first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Updated focused request',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Review details'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('form-review')),
          matching: find.text('Updated focused request'),
        ),
        findsOneWidget,
      );
      final reason = tester.widget<TextFormField>(
        find.byType(TextFormField).last,
      );
      expect(
        reason.controller!.text,
        'Please review this request for equipment.',
      );
      expect(find.text('Save request draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
