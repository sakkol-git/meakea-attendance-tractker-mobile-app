import 'package:flutter/material.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/widgets.dart';

class LiveAttendanceSummary extends StatelessWidget {
  final JsonMap report;
  const LiveAttendanceSummary({super.key, required this.report});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${report['totalCount']} recorded sessions',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      const Text(
        'Recorded work and approved time corrections. Final daily absence, holiday and leave summaries are not available yet.',
      ),
      const SizedBox(height: 16),
      for (final row
          in (report['records'] as List).cast<Map<String, dynamic>>())
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Employee ${row['employeeId']}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text('Work date: ${row['workDate']}'),
                Text(
                  'Status: ${row['status'] == 'OPEN'
                      ? 'Open'
                      : row['status'] == 'COMPLETED'
                      ? 'Completed'
                      : row['status']}',
                ),
                Text('Check-in (UTC): ${row['clockIn'] ?? 'Unavailable'}'),
                Text('Check-out (UTC): ${row['clockOut'] ?? 'Not recorded'}'),
                Text('Assigned time zone: ${row['timezone'] ?? 'Unavailable'}'),
                Text(
                  'Worked minutes: ${row['clockIn'] == null ? 'Unavailable' : row['minutesWorked'] ?? 'In progress'}',
                ),
              ],
            ),
          ),
        ),
      if ((report['records'] as List).isEmpty)
        const Text('No recorded sessions are available.'),
    ],
  );
}
