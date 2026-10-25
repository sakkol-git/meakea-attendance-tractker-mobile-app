import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/features/leave/data/repository.dart';

class SharedContractSource implements DataSource {
  final JsonMap fixture;
  final requests = <DataRequest>[];
  bool stale = false;
  SharedContractSource(this.fixture);
  @override
  String get mode => 'remote';
  @override
  Future<DataResponse> send(DataRequest request) async {
    requests.add(request);
    if (request.method == 'GET') {
      return DataResponse(
        200,
        fixture['before'],
        etag: fixture['etag'] as String,
      );
    }
    if (stale) {
      throw const DataFailure(412, 'STALE_VERSION', 'Refresh and review.');
    }
    return DataResponse(
      200,
      fixture['after'],
      etag: fixture['nextEtag'] as String,
    );
  }

  @override
  void close() {}
}

void main() {
  final fixture = jsonDecode(
    File('contracts/fixtures/leave-approval.json').readAsStringSync(),
  ) as JsonMap;
  test('shared leave contract passes through the feature repository', () async {
    final source = SharedContractSource(fixture);
    final repository = LeaveDataRepository(ClientData.forTest(source));
    final before = await repository.detail('leave', fixture['id'] as String);
    expect(before.id, fixture['before']['id']);
    expect(before.version, fixture['before']['version']);
    expect(before.etag, fixture['etag']);
    final after = await repository.decide(
      before,
      'approve',
      'Reviewed',
      fixture['idempotencyKey'] as String,
    );
    expect(after.status, fixture['after']['status']);
    expect(after.version, fixture['after']['version']);
    expect(after.etag, fixture['nextEtag']);
    final command = source.requests.last;
    expect(command.method, 'POST');
    expect(command.path, '/leave/requests/${fixture['id']}/approve');
    expect(command.ifMatch, fixture['etag']);
    expect(command.idempotencyKey, fixture['idempotencyKey']);
    expect(command.body, fixture['mobileBody']);
  });
  test('stale approval remains an error with no synthetic success', () async {
    final source = SharedContractSource(fixture)..stale = true;
    final repository = LeaveDataRepository(ClientData.forTest(source));
    final before = await repository.detail('leave', fixture['id'] as String);
    await expectLater(
      repository.decide(
        before,
        'approve',
        'Reviewed',
        fixture['idempotencyKey'] as String,
      ),
      throwsA(
        isA<DataFailure>().having((error) => error.status, 'status', 412),
      ),
    );
    expect(source.requests.where((r) => r.method == 'POST'), hasLength(1));
  });
}
