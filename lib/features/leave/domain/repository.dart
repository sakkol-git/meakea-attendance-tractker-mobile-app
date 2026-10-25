import 'package:hrflow_mobile/shared/domain/cases.dart';
import 'package:hrflow_mobile/features/leave/domain/models.dart';
import 'package:hrflow_mobile/shared/domain/resource_gateway.dart';
import 'package:hrflow_mobile/features/workflows/domain/repository.dart';
import 'package:hrflow_mobile/features/attachments/domain/repository.dart';

abstract interface class LeaveRepository
    implements
        CaseGateway,
        ResourceGateway,
        WorkflowRepository,
        AttachmentsRepository {
  Future<List<LeaveBalance>> balances();
  Future<LeavePreview> preview(
    String typeId,
    String startDate,
    String endDate,
    String portion,
  );
}
