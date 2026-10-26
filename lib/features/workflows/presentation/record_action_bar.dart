import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/core/design_tokens.dart';
import 'package:hrflow_mobile/shared/domain/workflow.dart';
import 'package:hrflow_mobile/shared/domain/workflow_policy.dart';
import 'package:hrflow_mobile/features/identity/domain/models.dart';

class RecordActionBar extends StatelessWidget {
  final WorkflowRecord record;
  final Profile actor;
  final Future<void> Function(String action) decide;
  final Future<void> Function() onFulfill;
  const RecordActionBar({
    super.key,
    required this.record,
    required this.actor,
    required this.decide,
    required this.onFulfill,
  });

  @override
  Widget build(BuildContext context) {
    final actions = WorkflowPolicy.actions(actor, record);
    if (actions.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Material(
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x2,
            AppSpacing.x4,
            AppSpacing.x2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (actions.contains('submit')) ...[
                BusyButton(
                  label: 'Submit request',
                  icon: Icons.send_outlined,
                  action: () => decide('submit'),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/edit/request/${record.id}'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit draft'),
                ),
              ],
              if (actions.contains('approve')) ...[
                BusyButton(
                  label: 'Approve request',
                  icon: Icons.check,
                  action: () => decide('approve'),
                ),
                OutlinedButton.icon(
                  onPressed: () => decide('reject'),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject request'),
                ),
              ],
              if (actions.contains('cancel'))
                TextButton(
                  onPressed: () => decide('cancel'),
                  child: const Text('Cancel request'),
                ),
              if (actions.contains('fulfill'))
                BusyButton(
                  label: 'Issue approved materials',
                  icon: Icons.inventory_2_outlined,
                  action: onFulfill,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
