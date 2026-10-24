import 'package:hrflow_mobile/features/identity/domain/models.dart';
import 'package:hrflow_mobile/shared/domain/workflow.dart';

/// Presentation eligibility only. The server must independently enforce authorization.
abstract final class WorkflowPolicy {
  static Set<String> actions(Profile actor, WorkflowRecord record) {
    final mine = record.employeeId == actor.id;
    return {
      if (mine && record.status == 'DRAFT') 'submit',
      if (mine &&
          record.kind != 'correction' &&
          (['DRAFT', 'PENDING'].contains(record.status) ||
              (record.kind == 'leave' &&
                  record.status == 'APPROVED' &&
                  record.fields['canCancel'] == true)))
        'cancel',
      if (!mine &&
          actor.manages &&
          record.status == 'PENDING' &&
          (record.fields['currentApproverId'] == null ||
              record.fields['currentApproverId'] == actor.id) &&
          (record.fields['approvalStage'] != 'HR' || actor.administers)) ...{
        'approve',
        'reject',
      },
      if (!mine &&
          actor.administers &&
          record.status == 'APPROVED' &&
          record.fields['type'] == 'MATERIAL')
        'fulfill',
    };
  }
}
