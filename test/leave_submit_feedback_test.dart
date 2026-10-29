import 'dart:async';
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
import 'package:hrflow_mobile/features/leave/domain/models.dart';

import 'support/workspace_fixture.dart';

class DelayedLeaveRepository extends HrRepository {
  DelayedLeaveRepository(super.client);
  final response = Completer<LeavePreview>();
  @override
  Future<LeavePreview> preview(
    String typeId,
    String startDate,
    String endDate,
    String portion,
  ) => response.future;
}

class SubmitSettings extends SettingsController {
  @override
  Settings build() => const Settings();
}

void main() {
  testWidgets(
    'send is visibly busy while checking the leave preview and recovers without losing input',
    (tester) async {
      final source = LocalDataSource(
        jsonDecode(File('assets/data/demo-seed.json').readAsStringSync())
            as JsonMap,
        populate: true,
        now: () => DateTime.utc(2026, 10, 23, 3),
      );
      final client = ClientData.forTest(source);
      final repository = DelayedLeaveRepository(client);
      final container = ProviderContainer(
        overrides: [
          clientProvider.overrideWithValue(client),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 23, 10)),
          ...testRepositoryOverrides(repository),
          settingsProvider.overrideWith(SubmitSettings.new),
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
      container.read(routerProvider).go('/new/leave');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annual leave').last);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(
        find.byType(TextFormField).last,
        'Family appointment',
      );
      await tester.tap(find.text('Send for approval'));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      final submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Saving…'),
      );
      expect(submit.onPressed, isNull);
      repository.response.completeError(
        const DataFailure(
          503,
          'UNAVAILABLE',
          'Leave preview is temporarily unavailable.',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Send for approval'), findsOneWidget);
      expect(find.text('Family appointment'), findsOneWidget);
      expect(
        find.textContaining('Leave preview is temporarily unavailable.'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
