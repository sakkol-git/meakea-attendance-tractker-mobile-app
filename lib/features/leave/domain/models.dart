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
