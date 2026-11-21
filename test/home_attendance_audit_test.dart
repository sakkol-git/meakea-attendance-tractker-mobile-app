import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/app.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/features/attendance/domain/models.dart';
import 'package:hrflow_mobile/features/dashboard/presentation/attendance_clock_card.dart';

import 'support/workspace_fixture.dart';
import 'visual_test.dart' show visualClient, VisualSettings;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final entry in {
      'KantumruyPro': 'assets/fonts/KantumruyPro[wght].ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(rootBundle.load(entry.value));
      await loader.load();
    }
  });
  testWidgets('shows the most recent clock times across multiple sessions', (
    tester,
  ) async {
    final morning = WorkSession(
      id: 'first',
      employeeId: 'employee',
      version: 1,
      clockIn: DateTime.utc(2026, 10, 23, 1),
      clockOut: DateTime.utc(2026, 10, 23, 5),
    );
    final afternoon = WorkSession(
      id: 'second',
      employeeId: 'employee',
      version: 1,
      clockIn: DateTime.utc(2026, 10, 23, 6),
    );
    for (final sessions in [
      [afternoon, morning],
      [morning, afternoon],
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            body: AttendanceClockCard(
              day: AttendanceDay('2026-10-23', sessions, null),
              record: (_) async {},
            ),
          ),
        ),
      );
      expect(find.text('Clock out'), findsOneWidget);
      expect(find.text('13:00'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);
    }
  });
  for (final size in [const Size(360, 800), const Size(768, 1024)]) {
    for (final dark in [false, true]) {
      testWidgets(
        'employee home clock action at ${size.width} in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
          tester.view.physicalSize = size;
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
          const boundary = ValueKey('home-audit');
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const RepaintBoundary(key: boundary, child: HrFlowApp()),
            ),
          );
          await tester.pumpAndSettle();
          await container.read(sessionProvider.notifier).demo('EMPLOYEE');
          await tester.pumpAndSettle();
          final button = find
              .descendant(
                of: find.byType(BusyButton),
                matching: find.bySubtype<FilledButton>(),
              )
              .first;
          final rect = tester.getRect(button);
          final before = tester
              .widget<BusyButton>(find.byType(BusyButton).first)
              .label;
          final expected = before == 'Clock in' ? 'Clock out' : 'Clock in';
          final semantics = tester.ensureSemantics();

          final outcomes = <String, String?>{};
          for (final entry in {
            'androidTapTarget': androidTapTargetGuideline,
            'iOSTapTarget': iOSTapTargetGuideline,
            'labeledTapTarget': labeledTapTargetGuideline,
            'textContrast': textContrastGuideline,
          }.entries) {
            final result = await entry.value.evaluate(tester);
            outcomes[entry.key] = result.passed ? null : result.reason;
          }
          semantics.dispose();
          final directory = Platform.environment['HRFLOW_UX_CAPTURE'];
          final name = '${size.width.toInt()}-${dark ? 'dark' : 'light'}';
          if (directory != null) {
            await tester.runAsync(() async {
              final image = await tester
                  .renderObject<RenderRepaintBoundary>(find.byKey(boundary))
                  .toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File('$directory/$name.png')
                  .writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.ensureVisible(button);
          final timer = Stopwatch()..start();
          await tester.tap(button);
          final confirmationFrames = await tester.pumpAndSettle();
          timer.stop();
          expect(find.widgetWithText(BusyButton, expected), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (directory != null) {
            File('$directory/$name.json').writeAsStringSync(
              const JsonEncoder.withIndent('  ').convert({
                'width': size.width,
                'height': size.height,
                'theme': dark ? 'dark' : 'light',
                'action': before,
                'confirmationAction': expected,
                'actionTopDp': rect.top,
                'actionHeightDp': rect.height,
                'confirmationPumps': confirmationFrames,
                'tapToSettledHarnessMs': timer.elapsedMicroseconds / 1000,
                'guidelines': outcomes,
              }),
            );
          }
          expect(
            outcomes.values.whereType<String>(),
            isEmpty,
            reason: outcomes.toString(),
          );
        },
      );
    }
  }
}
