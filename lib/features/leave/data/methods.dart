import 'mappers.dart';
import 'command_body.dart';

import 'package:hrflow_mobile/features/leave/domain/models.dart';
import 'package:hrflow_mobile/core/data/resource_repository.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/data/json.dart';

mixin LeaveMethods on ResourceRepository {
  Future<List<LeaveBalance>> balances() async =>
      (await collection('/leave/balances/me'))
          .map(LeaveBalanceMapper.fromJson)
          .toList();

  Future<LeavePreview> preview(
    String typeId,
    String startDate,
    String endDate,
    String portion,
  ) async {
    final row = object(
      (await client.request(
        DataRequest(
          'POST',
          '/leave/requests/preview',
          body: await leaveCommandBody(this, {
            'leaveTypeId': typeId,
            'startDate': startDate,
            'endDate': endDate,
            'portion': portion,
          }),
          idempotencyKey: commandKey(),
        ),
      )).data,
    );
    return LeavePreviewMapper.fromJson(row);
  }
}
