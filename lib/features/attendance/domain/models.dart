class WorkSession {
  final String id, employeeId, source, confirmation;
  final DateTime clockIn;
  final DateTime? clockOut;
  final int version;
  final String? revisionToken;
  const WorkSession({
    required this.id,
    required this.employeeId,
    required this.clockIn,
    this.clockOut,
    required this.version,
    this.revisionToken,
    this.source = 'TAP',
    this.confirmation = 'NONE',
  });
  String get etag => revisionToken ?? '"$version"';
  Duration get duration => (clockOut ?? DateTime.now()).difference(clockIn);
}

class AttendanceDay {
  final String date;
  final List<WorkSession> sessions;
  final String? shiftName;
  const AttendanceDay(this.date, this.sessions, this.shiftName);
}
