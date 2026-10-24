import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/features/workflows/presentation/decision_context.dart';
import 'package:hrflow_mobile/features/workflows/presentation/workflow_lists.dart';
import 'package:hrflow_mobile/shared/domain/workflow.dart';

WorkflowRecord _record(String kind, Map<String, dynamic> fields) =>
    WorkflowRecord(
      id: 'one',
      employeeId: 'employee',
      employeeName: 'Sok Dara',
      title: 'Review request',
      status: 'PENDING',
      reason: 'Review',
      kind: kind,
      version: 1,
      fields: fields,
    );

void main() {
  testWidgets('leave context names charge, balance, team coverage and stages', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: DecisionContext(
              _record('leave', {
                'reviewContext': {
                  'chargeableDays': 1.5,
                  'balanceAfter': 3.25,
                  'teamMembersOff': ['Chan Sopheak', 'Vann Rith'],
                  'steps': [
                    {'actor': 'Manager', 'action': 'APPROVED'},
                  ],
                  'nextReviewer': 'HR reviewer',
                },
              }),
            ),
          ),
        ),
      ),
    );
    expect(find.text('1.5 days'), findsOneWidget);
    expect(find.text('3.25 days'), findsOneWidget);
    expect(find.text('Chan Sopheak, Vann Rith'), findsOneWidget);
    expect(find.text('Manager · APPROVED'), findsOneWidget);
    expect(find.text('HR reviewer'), findsOneWidget);
  });

  testWidgets('material context shows requested against available stock', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          body: DecisionContext(
            _record('request', {
              'reviewContext': {
                'materials': [
                  {
                    'name': 'External monitor',
                    'requested': 2,
                    'stockAvailable': 4,
                  },
                ],
              },
            }),
          ),
        ),
      ),
    );
    expect(find.text('External monitor'), findsOneWidget);
    expect(find.text('2 requested · 4 in stock'), findsOneWidget);
  });
  testWidgets('approval card shows age and a policy exception', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          body: WorkflowTile(
            _record('leave', {
              'createdAt': '2026-10-20T03:00:00Z',
              'policyExceptions': ['Low team coverage'],
            }),
            now: DateTime.utc(2026, 10, 23, 3),
          ),
        ),
      ),
    );
    expect(find.text('Waiting 3d'), findsOneWidget);
    expect(find.text('Policy exception'), findsOneWidget);
  });
}
