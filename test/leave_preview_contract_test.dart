import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';

import 'support/workspace_fixture.dart';

class PreviewServer implements DataSource {
  final Map<String, dynamic> response;
  PreviewServer(this.response);
  @override
  String get mode => 'remote';
  @override
  Future<DataResponse> send(DataRequest request) async {
    if (request.path == '/leave/types') {
      return const DataResponse(200, {
        'items': [
          {'id': 'annual', 'code': 'ANNUAL', 'name': 'Annual'},
        ],
        'total': 1,
      });
    }
    return DataResponse(200, response);
  }

  @override
  void close() {}
}

Map<String, dynamic> preview({bool tracked = false}) => {
  'chargeableDays': 1,
  'balanceTracked': tracked,
  'balanceBefore': tracked ? 5 : null,
  'balanceAfter': tracked ? 4 : null,
  'allowHalfDay': true,
  'evidenceRequired': false,
  'minimumNoticeDays': 0,
  'warnings': <String>[],
};

void main() {
  Future<dynamic> read(Map<String, dynamic> row) =>
      HrRepository(ClientData.forTest(PreviewServer(row)))
          .preview('annual', '2026-11-02', '2026-11-02', 'FULL_DAY');

  test('unpaid preview preserves explicitly untracked balances', () async {
    final value = await read(preview());
    expect(value.balanceBefore, isNull);
    expect(value.balanceAfter, isNull);
    expect(value.balanceTracked, isFalse);
    expect(value.warnings, isEmpty);
  });

  test('paid preview retains actual numeric balance amounts', () async {
    final value = await read(preview(tracked: true));
    expect(value.balanceBefore, 5);
    expect(value.balanceAfter, 4);
    expect(value.balanceTracked, isTrue);
  });

  test('older paid-only numeric preview remains readable', () async {
    final row = preview(tracked: true)..remove('balanceTracked');
    expect((await read(row)).balanceBefore, 5);
  });

  for (final malformed in [
    {...preview(tracked: true), 'balanceBefore': null},
    {...preview(tracked: true), 'balanceAfter': '4'},
    {...preview(tracked: true), 'balanceBefore': double.nan},
    {...preview(), 'balanceBefore': 0},
    {...preview(), 'balanceTracked': 'false'},
  ]) {
    test('malformed accounting preview is rejected: $malformed', () async {
      await expectLater(read(malformed), throwsA(isA<DataFailure>()));
    });
  }
}
