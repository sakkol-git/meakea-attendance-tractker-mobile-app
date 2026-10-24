import 'mappers.dart';

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
    String halfDay,
  ) async {
    final row = object(
      (await client.request(
        DataRequest(
          'POST',
          '/leave/requests/preview',
          body: {
            'leaveTypeId': typeId,
            'startDate': startDate,
            'endDate': endDate,
            'halfDay': halfDay,
          },
          idempotencyKey: commandKey(),
        ),
      )).data,
    );
    return LeavePreview(
      chargeableDays: number(row, 'chargeableDays'),
      balanceBefore: number(row, 'balanceBefore'),
      balanceAfter: number(row, 'balanceAfter'),
      allowHalfDay: row['allowHalfDay'] == true,
      evidenceRequired: row['evidenceRequired'] == true,
      minimumNoticeDays: requiredInt(row, 'minimumNoticeDays'),
      warnings: (row['warnings'] as List? ?? []).cast<String>(),
    );
  }
}
