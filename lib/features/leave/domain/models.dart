class LeaveBalance {
  final String id, name;
  final double entitled, used, pending, available;
  final int? year;
  const LeaveBalance(
    this.id,
    this.name,
    this.entitled,
    this.used,
    this.pending,
    this.available, {
    this.year,
  });
}

class LeavePreview {
  final double chargeableDays, balanceBefore, balanceAfter;
  final bool allowHalfDay, evidenceRequired;
  final int minimumNoticeDays;
  final List<String> warnings;
  const LeavePreview({
    required this.chargeableDays,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.allowHalfDay,
    required this.evidenceRequired,
    required this.minimumNoticeDays,
    required this.warnings,
  });
}
