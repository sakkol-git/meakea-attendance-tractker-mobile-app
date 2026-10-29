import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/features/leave/domain/models.dart';
import 'package:hrflow_mobile/features/leave/presentation/preview_panel.dart';

void main() {
  testWidgets(
    'unpaid preview labels untracked balances without displaying zero',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: Scaffold(
            body: LeavePreviewPanel(
              preview: LeavePreview(
                chargeableDays: 1,
                balanceBefore: null,
                balanceAfter: null,
                balanceTracked: false,
                allowHalfDay: true,
                evidenceRequired: false,
                minimumNoticeDays: 0,
                warnings: [],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Not tracked'), findsNWidgets(2));
      expect(find.text('0 days'), findsNothing);
      expect(find.text('1 day'), findsOneWidget);
    },
  );

  testWidgets('paid preview retains amounts and evidence selection', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          body: LeavePreviewPanel(
            preview: const LeavePreview(
              chargeableDays: 0.5,
              balanceBefore: 5,
              balanceAfter: 4.5,
              balanceTracked: true,
              allowHalfDay: true,
              evidenceRequired: true,
              minimumNoticeDays: 0,
              warnings: [],
            ),
            chooseEvidence: () => selected = true,
          ),
        ),
      ),
    );
    expect(find.text('5 days'), findsOneWidget);
    expect(find.text('4.5 days'), findsOneWidget);
    await tester.tap(find.text('Choose PDF or image'));
    expect(selected, isTrue);
  });
}
