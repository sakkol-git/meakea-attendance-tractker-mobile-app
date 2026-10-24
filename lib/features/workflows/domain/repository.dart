import 'package:hrflow_mobile/features/attachments/domain/repository.dart';
import 'package:hrflow_mobile/shared/domain/workflow.dart';
import 'package:hrflow_mobile/shared/domain/resource_gateway.dart';

abstract interface class WorkflowRepository
    implements ResourceGateway, AttachmentsRepository {
  Future<void> updateDraft(WorkflowRecord record, String title, String reason);
  Future<RecordPage> recordsPage(
    String kind, {
    bool pending = false,
    int page = 0,
    int size = 25,
    String search = '',
    String status = '',
    String sort = '',
  });
  Future<List<WorkflowRecord>> records(String kind, {bool pending = false});
  Future<WorkflowRecord> detail(String kind, String id);
  Future<WorkflowRecord> create(
    String kind,
    Map<String, dynamic> body,
    String key,
  );
  Future<WorkflowRecord> decide(
    WorkflowRecord record,
    String action,
    String note,
    String key,
  );
}
