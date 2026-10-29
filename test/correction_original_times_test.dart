import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/features/attendance/presentation/correction_original_times.dart';

void main() {
  testWidgets(
    'missing original evidence is unknown, not an assertion that no session existed',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(body: CorrectionOriginalTimes()),
        ),
      );
      expect(find.textContaining('not available'), findsOneWidget);
      expect(find.text('No recorded session'), findsNothing);
    },
  );
  testWidgets(
    'authoritative empty snapshot explicitly shows no original session',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(body: CorrectionOriginalTimes(sessions: [])),
        ),
      );
      expect(find.text('No recorded session'), findsOneWidget);
    },
  );
}
