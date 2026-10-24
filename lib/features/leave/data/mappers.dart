import 'package:hrflow_mobile/core/data/json.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/leave/domain/models.dart';

abstract final class LeaveBalanceMapper {
  static LeaveBalance fromJson(JsonMap j) => LeaveBalance(
    requiredText(j, 'leaveTypeId'),
    j['name'] as String? ?? 'Leave',
    number(j, 'entitled'),
    number(j, 'used'),
    number(j, 'pending'),
    number(j, 'available'),
  );
}
