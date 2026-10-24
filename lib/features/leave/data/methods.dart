import 'mappers.dart';

import 'package:hrflow_mobile/features/leave/domain/models.dart';
import 'package:hrflow_mobile/core/data/resource_repository.dart';

mixin LeaveMethods on ResourceRepository {
  Future<List<LeaveBalance>> balances() async =>
      (await collection('/leave/balances/me'))
          .map(LeaveBalanceMapper.fromJson)
          .toList();
}
