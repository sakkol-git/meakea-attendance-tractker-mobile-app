/// The launch company zone is Asia/Phnom_Penh (UTC+07, without DST).
abstract final class CorrectionTime {
  static const companyOffset = Duration(hours: 7);
  static const maximumDuration = Duration(hours: 24);

  static DateTime instant(DateTime date, int hour, int minute) => DateTime.utc(
    date.year,
    date.month,
    date.day,
    hour,
    minute,
  ).subtract(companyOffset);

  static String? validate(DateTime start, DateTime end, DateTime now) {
    if (!end.isAfter(start)) {
      return 'Clock-out must be after clock-in. Choose the next date for an overnight shift.';
    }
    if (end.difference(start) > maximumDuration) {
      return 'A correction cannot exceed 24 hours.';
    }
    if (start.isAfter(now) || end.isAfter(now)) {
      return 'A correction cannot include a future time.';
    }
    return null;
  }

  static String display(DateTime? instant) {
    if (instant == null) return 'Not recorded';
    final local = instant.toUtc().add(companyOffset);
    final date =
        '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}
