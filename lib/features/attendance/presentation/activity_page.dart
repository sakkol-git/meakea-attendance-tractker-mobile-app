import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/features/workflows/presentation/workflow_pages.dart';

class ActivityPage extends ConsumerStatefulWidget {
  const ActivityPage({super.key});
  @override
  ConsumerState<ActivityPage> createState() => _ActivityState();
}

class _ActivityState extends ConsumerState<ActivityPage> {
  bool corrections = false;
  DateTimeRange? range;
  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Attendance',
    subtitle: 'A clear record of your workdays.',
    actions: [
      IconButton(
        tooltip: 'Filter by date',
        onPressed: () async {
          final now = DateTime.now();
          final selected = await showDateRangePicker(
            context: context,
            firstDate: now.subtract(const Duration(days: 730)),
            lastDate: now,
            initialDateRange: range,
          );
          if (selected != null) setState(() => range = selected);
        },
        icon: const Icon(Icons.date_range_outlined),
      ),
    ],
    onRefresh: () async {
      ref.invalidate(sessionsProvider);
      ref.invalidate(recordsProvider('correction'));
      await ref.read(sessionsProvider.future);
    },
    children: [
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Attendance')),
          ButtonSegment(value: true, label: Text('Corrections')),
        ],
        selected: {corrections},
        onSelectionChanged: (s) => setState(() => corrections = s.first),
      ),
      const SizedBox(height: 20),
      if (range != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: InputChip(
            label: Text(
              '${shortDate(range!.start.toString())} – ${shortDate(range!.end.toString())}',
            ),
            onDeleted: () => setState(() => range = null),
          ),
        ),
      if (corrections)
        AsyncPanel(
          value: ref.watch(recordsProvider('correction')),
          retry: () => ref.invalidate(recordsProvider('correction')),
          builder: (rows) => rows.isEmpty
              ? EmptyState(
                  title: 'No corrections',
                  description:
                      'If something looks wrong, send a correction for review.',
                  action: TextButton(
                    onPressed: () => context.push('/new/correction'),
                    child: const Text('Report an issue'),
                  ),
                )
              : Column(
                  children: [
                    ...rows.map(WorkflowTile.new),
                    if (ref
                        .read(recordsProvider('correction').notifier)
                        .canLoadMore)
                      BusyButton(
                        label: 'Load more corrections',
                        action: () => ref
                            .read(recordsProvider('correction').notifier)
                            .loadMore(),
                      ),
                  ],
                ),
        )
      else
        AsyncPanel(
          value: ref.watch(sessionsProvider),
          retry: () => ref.invalidate(sessionsProvider),
          builder: (all) {
            final sessions = all.where((s) {
              final d = s.clockIn.toUtc().add(const Duration(hours: 7));
              return range == null ||
                  !d.isBefore(range!.start) &&
                      d.isBefore(range!.end.add(const Duration(days: 1)));
            }).toList();
            if (sessions.isEmpty) {
              return const EmptyState(
                title: 'Your days start here',
                description:
                    'Clock in from Home to start your attendance record.',
                icon: Icons.schedule_outlined,
              );
            }
            final duration = sessions
                .where(
                  (s) => s.clockOut != null && s.confirmation != 'REJECTED',
                )
                .fold<Duration>(Duration.zero, (v, s) => v + s.duration);
            return Column(
              children: [
                Surface(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Recorded time',
                              style: TextStyle(color: Palette.muted),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              durationText(duration),
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${sessions.length} sessions',
                        style: const TextStyle(color: Palette.teal),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                for (final s in sessions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  shortDate(
                                    s.clockIn
                                        .toUtc()
                                        .add(const Duration(hours: 7))
                                        .toString(),
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              StatusPill(
                                s.confirmation == 'PENDING'
                                    ? 'REVIEW_NEEDED'
                                    : [
                                        'REJECTED',
                                        'CONFIRMED',
                                      ].contains(s.confirmation)
                                    ? s.confirmation
                                    : s.clockOut == null
                                    ? 'OPEN'
                                    : 'COMPLETED',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Clock in',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Palette.muted,
                                      ),
                                    ),
                                    Text(
                                      timeText(s.clockIn),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Clock out',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Palette.muted,
                                      ),
                                    ),
                                    Text(
                                      timeText(s.clockOut),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                              if (s.clockOut != null)
                                Text(
                                  durationText(s.duration),
                                  style: const TextStyle(
                                    color: Palette.teal,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                          if (s.confirmation == 'PENDING') ...[
                            const SizedBox(height: 12),
                            BusyButton(
                              label: 'Confirm this record',
                              action: () async {
                                await ref
                                    .read(attendanceRepositoryProvider)
                                    .command(
                                      '/attendance/sessions/${s.id}/confirm',
                                      etag: s.etag,
                                    );
                                ref.invalidate(sessionsProvider);
                              },
                            ),
                            const SizedBox(height: 8),
                            BusyButton(
                              label: 'Reject this record',
                              action: () async {
                                await ref
                                    .read(attendanceRepositoryProvider)
                                    .command(
                                      '/attendance/sessions/${s.id}/reject',
                                      etag: s.etag,
                                      body: {
                                        'reason': 'Employee disputes the inferred attendance record.',
                                      },
                                    );
                                ref.invalidate(sessionsProvider);
                              },
                            ),
                          ],
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.push('/new/correction'),
                              child: const Text('Report an issue'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => context.push('/new/correction'),
        icon: const Icon(Icons.edit_calendar_outlined),
        label: const Text('Request a correction'),
      ),
    ],
  );
}
