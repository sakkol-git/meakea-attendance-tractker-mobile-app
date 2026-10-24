import 'package:flutter/material.dart';

import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/core/leave_quantity.dart';
import 'package:hrflow_mobile/shared/domain/workflow.dart';

class DecisionContext extends StatelessWidget {
  final WorkflowRecord record;
  const DecisionContext(this.record, {super.key});

  @override
  Widget build(BuildContext context) {
    final values = record.fields['reviewContext'];
    final review = values is Map
        ? Map<String, dynamic>.from(values)
        : const <String, dynamic>{};
    final steps = review['steps'] as List? ?? const [];
    final materials = review['materials'] as List? ?? const [];
    final teamOff = review['teamMembersOff'] as List? ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Decision context'),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (record.kind == 'leave') ...[
                InfoRow(
                  'Chargeable days',
                  formatLeaveDays(
                    (review['chargeableDays'] ?? record.fields['days']) as num?,
                  ),
                ),
                InfoRow(
                  'Balance after',
                  review['balanceAfter'] is num
                      ? formatLeaveDays(review['balanceAfter'] as num)
                      : 'Not supplied',
                ),
                InfoRow('Team members off', '${teamOff.length}'),
                if (teamOff.isNotEmpty) Text(teamOff.join(', ')),
              ],
              if (record.kind == 'correction')
                const Text(
                  'Compare the original and proposed dated times above.',
                ),
              for (final item in materials)
                if (item is Map)
                  InfoRow(
                    '${item['name']}',
                    '${item['requested']} requested · ${item['stockAvailable']} in stock',
                  ),
              if (review.isEmpty)
                const Text(
                  'Review impact has not been supplied by the server.',
                ),
              const Divider(height: 24),
              InfoRow('Completed stages', '${steps.length}'),
              for (final step in steps)
                if (step is Map)
                  Text(
                    '${step['actor'] ?? 'Reviewer'} · ${step['action'] ?? 'Reviewed'}',
                  ),
              InfoRow(
                'Next reviewer',
                '${review['nextReviewer'] ?? 'Not supplied'}',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
