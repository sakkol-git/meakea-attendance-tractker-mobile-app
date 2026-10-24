class ApprovalDelegation {
  final String id, delegateId, delegateName, startsOn, endsOn, status, etag;
  const ApprovalDelegation({
    required this.id,
    required this.delegateId,
    required this.delegateName,
    required this.startsOn,
    required this.endsOn,
    required this.status,
    required this.etag,
  });

  factory ApprovalDelegation.fromJson(Map<String, dynamic> json) =>
      ApprovalDelegation(
        id: json['id'] as String,
        delegateId: json['delegateId'] as String,
        delegateName:
            json['delegateName'] as String? ?? json['delegateId'] as String,
        startsOn: json['startsOn'] as String,
        endsOn: json['endsOn'] as String,
        status: json['status'] as String,
        etag: json['etag'] as String? ?? '"${json['version']}"',
      );
}

class EligibleDelegate {
  final String id, name;
  const EligibleDelegate(this.id, this.name);
  factory EligibleDelegate.fromJson(Map<String, dynamic> json) =>
      EligibleDelegate(json['id'] as String, json['name'] as String);
}
