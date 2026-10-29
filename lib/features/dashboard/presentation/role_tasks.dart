import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/features/identity/domain/models.dart';

/// The first work card uses live repository data, never a demo-only counter.
class RoleTasks extends ConsumerWidget {
  final Profile profile;
  const RoleTasks(this.profile, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!profile.manages) return const SizedBox.shrink();
    final pending = ref.watch(approvalProvider);
    final now = ref.read(clockProvider)();
    final rows = pending.asData?.value ?? const [];
    final created =
        rows
            .map((row) => DateTime.tryParse('${row.fields['createdAt'] ?? ''}'))
            .whereType<DateTime>()
            .toList()
          ..sort();
    final oldestDays = created.isEmpty
        ? null
        : now.difference(created.first).inDays;
    final corrections = rows.where((row) => row.kind == 'correction').length;
    final attendance = profile.administers
        ? ref.watch(teamAttendanceProvider)
        : null;
    final openSessions = attendance?.asData?.value
        .where((row) => row.clockOut == null)
        .length;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Surface(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.administers
                  ? 'Exceptions to review'
                  : 'Needs my decision',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              pending.hasError
                  ? 'Approval counts are unavailable. Open the queue or pull to refresh.'
                  : pending.isLoading
                  ? 'Loading current work…'
                  : '${rows.length} pending ${rows.length == 1 ? 'approval' : 'approvals'}${oldestDays == null ? '' : ' · oldest ${oldestDays < 0 ? 0 : oldestDays} ${oldestDays == 1 ? 'day' : 'days'}'}',
            ),
            if (profile.administers && !pending.hasError && !pending.isLoading)
              Text(
                '$corrections pending ${corrections == 1 ? 'correction' : 'corrections'} · ${attendance?.hasError == true
                    ? 'attendance unavailable'
                    : openSessions == null
                    ? 'attendance loading'
                    : '$openSessions open attendance ${openSessions == 1 ? 'session' : 'sessions'}'}',
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.push('/approvals'),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Open approval queue'),
              ),
            ),
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: () => context.push('/team-attendance'),
                  child: const Text('Team attendance'),
                ),
                if (profile.administers)
                  TextButton(
                    onPressed: () => context.push('/directory'),
                    child: const Text('People directory'),
                  ),
                if (profile.role == 'OWNER')
                  TextButton(
                    onPressed: () => context.push('/audit'),
                    child: const Text('Audit activity'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
