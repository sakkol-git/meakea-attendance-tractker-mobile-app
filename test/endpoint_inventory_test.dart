import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/data/case_repository.dart';
import 'package:hrflow_mobile/features/attendance/data/case_routes.dart';
import 'package:hrflow_mobile/features/identity/data/case_routes.dart';
import 'package:hrflow_mobile/features/leave/data/case_routes.dart';
import 'package:hrflow_mobile/features/notifications/data/case_routes.dart';
import 'package:hrflow_mobile/features/reporting/data/case_routes.dart';
import 'package:hrflow_mobile/features/requests/data/case_routes.dart';

void main() {
  test('the handover endpoint inventory matches feature-owned adapters', () {
    final expected = <String, Map<String, CaseRoute>>{
      'attendance': attendanceCaseRoutes,
      'identity': identityCaseRoutes,
      'leave': leaveCaseRoutes,
      'notifications': notificationsCaseRoutes,
      'reporting': reportingCaseRoutes,
      'requests': requestsCaseRoutes,
      'operations': const {
        'operations.readiness': CaseRoute('/operations/workflow-status'),
      },
    };
    final document = jsonDecode(
      File('docs/validation/feature-endpoints.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(document['status'], 'PROVISIONAL_CLIENT_REQUIREMENTS');
    final rows = (document['routes'] as List).cast<Map<String, dynamic>>();
    final actual = {
      for (final row in rows)
        '${row['feature']}:${row['key']}': (
          row['method'],
          row['path'],
          row['versioned'],
        ),
    };
    final fromCode = {
      for (final feature in expected.entries)
        for (final route in feature.value.entries)
          '${feature.key}:${route.key}': (
            route.value.method,
            route.value.path,
            route.value.versioned,
          ),
    };
    expect(rows.length, actual.length, reason: 'No duplicate route entries');
    expect(actual, fromCode);
  });
}
