import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/identity/domain/models.dart';
import 'package:hrflow_mobile/shared/domain/workflow.dart';

import '../domain/repository.dart';

import 'package:hrflow_mobile/shared/domain/workflow_policy.dart';

/// Application orchestration shared by screens and tests; no Flutter or transport dependency.
class WorkflowUseCases {
  final WorkflowRepository repository;
  const WorkflowUseCases(this.repository);
  Future<WorkflowRecord> create(
    String kind,
    Map<String, dynamic> input,
    String commandKey,
  ) {
    if (!['leave', 'request', 'correction'].contains(kind)) {
      throw const DataFailure(
        422,
        'VALIDATION_ERROR',
        'Unsupported request type.',
      );
    }
    final reason = (input['reason'] as String? ?? '').trim();
    if (reason.length < 5) {
      throw const DataFailure(
        422,
        'VALIDATION_ERROR',
        'A clear reason is required.',
      );
    }
    return repository.create(kind, Map.unmodifiable(input), commandKey);
  }

  Future<WorkflowRecord> decide(
    Profile actor,
    WorkflowRecord record,
    String action,
    String note,
    String key,
  ) {
    if (!WorkflowPolicy.actions(actor, record).contains(action)) {
      throw const DataFailure(
        403,
        'FORBIDDEN',
        'This action is not available to this account.',
      );
    }
    if (action == 'reject' && note.trim().length < 5) {
      throw const DataFailure(
        422,
        'VALIDATION_ERROR',
        'A rejection reason is required.',
      );
    }
    return repository.decide(record, action, note.trim(), key);
  }
}
