import 'package:hrflow_mobile/core/data/json.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/leave/domain/models.dart';

abstract final class LeaveBalanceMapper {
  static LeaveBalance fromJson(JsonMap j) => LeaveBalance(
    requiredText(j, j.containsKey('type') ? 'type' : 'leaveTypeId'),
    j['name'] as String? ?? 'Leave',
    number(j, 'entitled'),
    number(j, 'used'),
    number(j, 'pending'),
    number(j, 'available'),
    year: j['year'] as int?,
  );
}

abstract final class LeavePreviewMapper {
  static LeavePreview fromJson(JsonMap row) {
    // Older paid-only providers and the local demo omit the additive flag.
    final tracked = row.containsKey('balanceTracked')
        ? row['balanceTracked']
        : true;
    if (tracked is! bool ||
        (!tracked &&
            (!row.containsKey('balanceBefore') ||
                !row.containsKey('balanceAfter') ||
                row['balanceBefore'] != null ||
                row['balanceAfter'] != null))) {
      throw const DataFailure(
        0,
        'CONTRACT_MISMATCH',
        'The server returned inconsistent leave accounting.',
      );
    }
    return LeavePreview(
      chargeableDays: number(row, 'chargeableDays'),
      balanceBefore: tracked ? number(row, 'balanceBefore') : null,
      balanceAfter: tracked ? number(row, 'balanceAfter') : null,
      balanceTracked: tracked,
      allowHalfDay: row['allowHalfDay'] == true,
      evidenceRequired: row['evidenceRequired'] == true,
      minimumNoticeDays: requiredInt(row, 'minimumNoticeDays'),
      warnings: (row['warnings'] as List? ?? []).cast<String>(),
    );
  }
}
