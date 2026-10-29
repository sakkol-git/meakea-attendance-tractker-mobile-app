import 'package:hrflow_mobile/core/data/json.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/identity/domain/models.dart';

abstract final class ProfileMapper {
  static Profile fromJson(JsonMap j, {bool demo = false}) => Profile(
    id: requiredText(j, 'employeeId'),
    tenantId: requiredText(j, 'tenantId'),
    name: text(j, 'name', text(j, 'fullName', 'Your account')),
    email: text(j, 'email'),
    role: _role(j),
    grantedRoles: List<String>.unmodifiable(
      (j['roles'] as List).cast<String>(),
    ),
    demo: demo,
    department: text(j, 'department'),
    position: text(j, 'position'),
    organization: text(j, 'organization', 'HRFlow'),
    phone: text(j, 'phone'),
    timeZone: requiredText(j, 'timeZone'),
  );
}

String _role(JsonMap j) {
  final roles = j['roles'];
  if (roles is! List || roles.isEmpty || roles.any((r) => r is! String)) {
    throw const DataFailure(0, 'CONTRACT_MISMATCH', 'Missing account roles.');
  }
  return ['OWNER', 'HR_ADMIN', 'MANAGER', 'EMPLOYEE'].firstWhere(
    roles.contains,
    orElse: () => throw const DataFailure(
      403,
      'UNSUPPORTED_ROLE',
      'This account has no supported client role.',
    ),
  );
}

abstract final class ShiftMapper {
  static ShiftOption option(JsonMap j) => ShiftOption(
    requiredText(j, 'id'),
    requiredText(j, 'name'),
    requiredText(j, 'startTime'),
    requiredText(j, 'endTime'),
    text(j, 'days', 'By assignment'),
  );
  static ShiftAssignment assignment(JsonMap j) {
    final from = dateOnly(j, 'validFrom');
    final to = j['validTo'] == null ? null : dateOnly(j, 'validTo');
    if (to != null && to.compareTo(from) < 0) {
      throw const DataFailure(
        0,
        'CONTRACT_MISMATCH',
        'The API returned an invalid assignment interval.',
      );
    }
    final snapshot = j['shiftSnapshot'] is Map
        ? JsonMap.from(j['shiftSnapshot'] as Map)
        : const <String, dynamic>{};
    final site = snapshot['site'] is Map
        ? JsonMap.from(snapshot['site'] as Map)
        : const <String, dynamic>{};
    return ShiftAssignment(
      id: requiredText(j, 'id'),
      employeeId: requiredText(j, 'employeeId'),
      shiftId: requiredText(j, 'shiftId'),
      shiftName: text(j, 'shiftName', text(snapshot, 'name', 'Work shift')),
      timezone: text(snapshot, 'timezone'),
      siteName: text(site, 'name'),
      validFrom: from,
      validTo: to,
      version: requiredInt(j, 'version'),
    );
  }
}
