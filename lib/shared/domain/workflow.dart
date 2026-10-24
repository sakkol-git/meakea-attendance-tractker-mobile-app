class WorkflowRecord {
  final String id, employeeId, title, status, reason, kind, employeeName;
  final int version;
  final String? revisionToken;
  final Map<String, dynamic> fields;
  const WorkflowRecord({
    required this.id,
    required this.employeeId,
    required this.title,
    required this.status,
    required this.reason,
    required this.kind,
    required this.version,
    this.revisionToken,
    required this.fields,
    required this.employeeName,
  });
  String get etag => revisionToken ?? '"$version"';
  bool get terminal => ['REJECTED', 'CANCELLED', 'FULFILLED'].contains(status);
}

class RecordPage {
  final List<WorkflowRecord> records;
  final int total, page, size;
  const RecordPage(this.records, this.total, this.page, this.size);
  bool get hasMore => (page + 1) * size < total;
}
