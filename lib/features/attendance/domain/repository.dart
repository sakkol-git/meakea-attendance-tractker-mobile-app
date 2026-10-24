import 'package:hrflow_mobile/shared/domain/cases.dart';
import 'package:hrflow_mobile/features/attendance/domain/models.dart';
import 'package:hrflow_mobile/shared/domain/resource_gateway.dart';
import 'package:hrflow_mobile/features/workflows/domain/repository.dart';
import 'package:hrflow_mobile/features/attachments/domain/repository.dart';

abstract interface class AttendanceRepository
    implements
        CaseGateway,
        ResourceGateway,
        WorkflowRepository,
        AttachmentsRepository {
  Future<AttendanceDay> today();
  Future<List<WorkSession>> sessions({bool team = false});
  Future<void> clock({WorkSession? open, required String key});
}
