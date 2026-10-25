class Profile {
  final String id,
      name,
      email,
      role,
      department,
      position,
      organization,
      phone,
      tenantId,
      timeZone;
  const Profile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.department = '',
    this.position = '',
    this.organization = 'HRFlow',
    this.phone = '',
    this.tenantId = '',
    this.timeZone = 'Asia/Phnom_Penh',
  });
  bool get manages => ['MANAGER', 'HR_ADMIN', 'OWNER'].contains(role);
  bool get administers => ['HR_ADMIN', 'OWNER'].contains(role);
}

class ShiftOption {
  final String id, name, startTime, endTime, days;
  const ShiftOption(
    this.id,
    this.name,
    this.startTime,
    this.endTime,
    this.days,
  );
}

class ShiftAssignment {
  final String id, employeeId, shiftId, shiftName, validFrom;
  final String? validTo;
  final int version;
  const ShiftAssignment({
    required this.id,
    required this.employeeId,
    required this.shiftId,
    required this.shiftName,
    required this.validFrom,
    required this.validTo,
    required this.version,
  });
  bool includes(String date) =>
      validFrom.compareTo(date) <= 0 &&
      (validTo == null || validTo!.compareTo(date) >= 0);
}
