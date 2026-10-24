import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/widgets.dart';

class TeamAttendancePage extends ConsumerWidget {
  const TeamAttendancePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: 'Team attendance',
    subtitle: 'Recorded sessions for your authorized team.',
    onRefresh: () async {
      ref.invalidate(teamAttendanceProvider);
      await ref.read(teamAttendanceProvider.future);
    },
    children: [
      AsyncPanel(
        value: ref.watch(teamAttendanceProvider),
        retry: () => ref.invalidate(teamAttendanceProvider),
        builder: (rows) => rows.isEmpty
            ? const EmptyState(
                title: 'No sessions to review',
                description: 'Team attendance will appear when recorded.',
              )
            : Column(
                children: [
                  for (final session in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Surface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ref
                                      .watch(collectionProvider('/employees'))
                                      .asData
                                      ?.value
                                      .where(
                                        (p) => p['id'] == session.employeeId,
                                      )
                                      .firstOrNull?['name']
                                      ?.toString() ??
                                  'Team member',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            InfoRow(
                              'Date',
                              shortDate(session.clockIn.toString()),
                            ),
                            InfoRow('Clock in', timeText(session.clockIn)),
                            InfoRow('Clock out', timeText(session.clockOut)),
                            if (session.clockOut != null)
                              InfoRow(
                                'Worked time',
                                durationText(session.duration),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    ],
  );
}
