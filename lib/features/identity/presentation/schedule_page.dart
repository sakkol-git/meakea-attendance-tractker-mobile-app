import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/features/identity/presentation/assignments_page.dart';

class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: 'Schedule',
    subtitle: 'Plan your week with a little more clarity.',
    children: [
      const SectionTitle('Your assigned shifts'),
      ShiftAssignmentsSection(ref.watch(sessionProvider).profile!.id),
      const SectionTitle('Company shift rules'),
      AsyncPanel(
        value: ref.watch(collectionProvider('/shifts')),
        retry: () => ref.invalidate(collectionProvider('/shifts')),
        builder: (rows) => Column(
          children: [
            for (final s in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['name'] as String,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      InfoRow('Hours', '${s['startTime']} – ${s['endTime']}'),
                      InfoRow('Days', s['days'] as String? ?? 'By assignment'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      const SectionTitle('Upcoming holidays'),
      AsyncPanel(
        value: ref.watch(collectionProvider('/holidays')),
        retry: () => ref.invalidate(collectionProvider('/holidays')),
        builder: (rows) => rows.isEmpty
            ? const EmptyState(
                title: 'No holidays listed',
                description: 'Company holidays will appear here.',
              )
            : Column(
                children: [
                  for (final h in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Surface(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event_outlined,
                              color: Palette.teal,
                            ),
                            const SizedBox(width: 16),
                            Expanded(child: Text(h['name'] as String)),
                            Text(shortDate(h['date'] as String?)),
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
