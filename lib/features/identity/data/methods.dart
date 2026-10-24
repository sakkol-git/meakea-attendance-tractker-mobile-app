import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/data/json.dart';

import 'mappers.dart';

import 'package:hrflow_mobile/features/identity/domain/models.dart';
import 'package:hrflow_mobile/core/data/resource_repository.dart';

mixin IdentityMethods on ResourceRepository {
  Future<List<ShiftOption>> shiftOptions() async =>
      (await collection('/shifts')).map(ShiftMapper.option).toList();
  Future<List<ShiftAssignment>> shiftAssignments(String employeeId) async =>
      (await collection('/employees/$employeeId/shifts'))
          .map(ShiftMapper.assignment)
          .toList();
  Future<ShiftAssignment> assignShift(
    String employeeId,
    String shiftId,
    String validFrom,
    String? validTo,
    String key,
  ) async => ShiftMapper.assignment(
    object(
      (await command(
        '/employees/$employeeId/shifts',
        key: key,
        body: {'shiftId': shiftId, 'validFrom': validFrom, 'validTo': validTo},
      )).data,
    ),
  );
  Future<Profile> saveProfile(JsonMap values) async {
    // Explicit client extension; keep mapping here until the active backend contract is published.
    return ProfileMapper.fromJson(
      object(
        (await client.request(DataRequest('PATCH', '/profile', body: values)))
            .data,
      ),
    );
  }
}
