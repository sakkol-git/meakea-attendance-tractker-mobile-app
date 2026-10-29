import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';

import 'support/workspace_fixture.dart';

class ReportServer implements DataSource {
  @override
  String get mode => 'remote';
  String? path;
  @override
  Future<DataResponse> send(DataRequest request) async {
    path = request.path;
    return const DataResponse(200, {
      'totalCount': 1,
      'records': [
        {
          'employeeId': 'employee',
          'workDate': '2026-10-28',
          'status': 'OPEN',
          'minutesWorked': null,
          'clockIn': '2026-10-28T01:00:00Z',
          'clockOut': null,
          'timezone': 'Asia/Phnom_Penh',
          'source': 'TAP',
          'aggregateRevision': 1,
        },
      ],
    });
  }

  @override
  void close() {}
}

void main() {
  test(
    'remote report reads actual session summary and keeps unknown duration',
    () async {
      final server = ReportServer();
      final client = ClientData.forTest(server);
      final container = ProviderContainer(
        overrides: [
          clientProvider.overrideWithValue(client),
          ...testRepositoryOverrides(HrRepository(client)),
        ],
      );
      addTearDown(container.dispose);
      final report = await container.read(reportProvider.future);
      expect(server.path, '/reports/attendance/summary');
      expect(report['totalCount'], 1);
      expect((report['records'] as List).first['minutesWorked'], isNull);
      expect(report.containsKey('pendingLeave'), isFalse);
    },
  );
}
