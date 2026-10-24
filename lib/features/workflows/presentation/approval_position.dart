import 'package:hrflow_mobile/shared/domain/workflow.dart';

/// A small snapshot of the visible queue, retained while reviewing a detail.
class ApprovalPosition {
  final List<({String kind, String id})> items;
  final int index;
  ApprovalPosition(List<WorkflowRecord> records, this.index)
    : items = records
          .map((record) => (kind: record.kind, id: record.id))
          .toList();
  const ApprovalPosition._(this.items, this.index);

  ApprovalPosition? get next =>
      index + 1 < items.length ? ApprovalPosition._(items, index + 1) : null;
  ({String kind, String id}) get current => items[index];
}
