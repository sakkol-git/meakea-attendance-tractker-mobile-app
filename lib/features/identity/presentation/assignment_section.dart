import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/widgets.dart';

class ShiftAssignmentsSection extends ConsumerWidget {
  final String employeeId;
  const ShiftAssignmentsSection(this.employeeId, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncPanel(
      value: ref.watch(shiftAssignmentsProvider(employeeId)),
      retry: () => ref.invalidate(shiftAssignmentsProvider(employeeId)),
      builder: (rows) => rows.isEmpty
          ? const EmptyState(
              title: 'No assigned shifts',
              description: 'HR can assign a work schedule. Today’s schedule is unavailable until an assignment is confirmed.',
              icon: Icons.event_note_outlined,
            )
          : Column(
              children: [
                for (final assignment in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assignment.shiftName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (assignment.siteName.isNotEmpty)
                            InfoRow('Work site', assignment.siteName),
                          InfoRow(
                            'Site timezone',
                            assignment.timezone.isEmpty
                                ? 'Unavailable'
                                : assignment.timezone,
                          ),
                          InfoRow('First day', shortDate(assignment.validFrom)),
                          InfoRow(
                            'Last day',
                            assignment.validTo == null
                                ? 'No end date'
                                : shortDate(assignment.validTo),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
