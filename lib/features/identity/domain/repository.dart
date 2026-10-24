import 'package:hrflow_mobile/shared/domain/cases.dart';
import 'package:hrflow_mobile/features/identity/domain/models.dart';
import 'package:hrflow_mobile/shared/domain/resource_gateway.dart';

abstract interface class IdentityRepository
    implements CaseGateway, ResourceGateway {
  Future<List<ShiftOption>> shiftOptions();
  Future<List<ShiftAssignment>> shiftAssignments(String employeeId);
  Future<ShiftAssignment> assignShift(
    String employeeId,
    String shiftId,
    String validFrom,
    String? validTo,
    String key,
  );
  Future<Profile> saveProfile(Map<String, dynamic> values);
}
