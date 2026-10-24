import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';

class AuditPage extends ConsumerWidget {
  const AuditPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: 'Audit activity',
    subtitle: 'A record of decisions and changes.',
    children: [
      AsyncPanel(
        value: ref.watch(collectionProvider('/audit-logs')),
        retry: () => ref.invalidate(collectionProvider('/audit-logs')),
        builder: (rows) => rows.isEmpty
            ? const EmptyState(
                title: 'No activity yet',
                description: 'Recorded changes will appear here.',
                icon: Icons.history_outlined,
              )
            : Column(
                children: [
                  for (final r in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Surface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              statusLabel(r['action'] as String),
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${r['actor'] ?? r['actorId'] ?? ''} · ${shortDate(r['at'] as String?)}',
                              style: TextStyle(
                                color: context.semantic.textMuted,
                                fontSize: 12,
                              ),
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
