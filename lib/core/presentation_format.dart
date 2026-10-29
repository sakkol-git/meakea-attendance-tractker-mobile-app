String statusLabel(String status) => switch (status) {
  'REVIEW_NEEDED' => 'Review needed',
  'CONFIRMED' => 'Confirmed',
  'PENDING' => 'Pending approval',
  'APPROVED' => 'Approved',
  'REJECTED' => 'Rejected',
  'CANCELLED' => 'Cancelled',
  'DRAFT' => 'Draft',
  'FULFILLED' => 'Fulfilled',
  'COMPLETED' => 'Completed',
  _ =>
    status
        .replaceAll('_', ' ')
        .toLowerCase()
        .replaceFirstMapped(RegExp(r'^.'), (match) => match[0]!.toUpperCase()),
};

String shortDate(String? value) {
  final parsed = DateTime.tryParse(value ?? '');
  if (parsed == null) return value ?? '—';
  final date = value!.contains('T')
      ? parsed.toUtc().add(const Duration(hours: 7))
      : parsed;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String timeText(DateTime? value) {
  if (value == null) return 'Not recorded';
  final local = value.toUtc().add(const Duration(hours: 7));
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String companyTimestamp(String? value) {
  final instant = DateTime.tryParse(value ?? '');
  if (instant == null) return 'Time unavailable';
  final local = instant.toUtc().add(const Duration(hours: 7));
  final date = shortDate(local.toIso8601String().substring(0, 10));
  final clock =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
  return '$date · $clock UTC+07';
}

String durationText(Duration value) =>
    '${value.inHours}h ${value.inMinutes.remainder(60)}m';

String cachedResourceLabel(String path) =>
    switch (Uri.tryParse(path)?.pathSegments.firstOrNull) {
      'attendance' => 'Attendance',
      'leave' => 'Leave',
      'requests' => 'Requests',
      'notifications' => 'Notifications',
      'employees' || 'departments' || 'positions' => 'People',
      'reports' => 'Reports',
      'shifts' || 'holidays' || 'work-sites' => 'Company schedule',
      _ => 'Workspace information',
    };
