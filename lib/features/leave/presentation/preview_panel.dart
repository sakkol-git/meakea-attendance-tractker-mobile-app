import 'package:flutter/material.dart';
import 'package:hrflow_mobile/core/leave_quantity.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';

import '../domain/models.dart';

class LeavePreviewPanel extends StatelessWidget {
  final LeavePreview preview;
  final String? evidenceName;
  final VoidCallback? chooseEvidence;

  const LeavePreviewPanel({
    super.key,
    required this.preview,
    this.evidenceName,
    this.chooseEvidence,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Before you submit', style: Theme.of(context).textTheme.titleMedium),
      InfoRow('Chargeable', formatLeaveDays(preview.chargeableDays)),
      InfoRow(
        'Available before',
        preview.balanceTracked
            ? formatLeaveDays(preview.balanceBefore!)
            : 'Not tracked',
      ),
      InfoRow(
        'Balance after',
        preview.balanceTracked
            ? formatLeaveDays(preview.balanceAfter!)
            : 'Not tracked',
      ),
      if (preview.minimumNoticeDays > 0)
        InfoRow('Minimum notice', '${preview.minimumNoticeDays} days'),
      for (final warning in preview.warnings)
        Text(warning, style: TextStyle(color: context.semantic.error)),
      if (preview.evidenceRequired) ...[
        const Text('Supporting evidence is required before submission.'),
        OutlinedButton.icon(
          onPressed: chooseEvidence,
          icon: const Icon(Icons.attach_file),
          label: Text(evidenceName ?? 'Choose PDF or image'),
        ),
      ],
    ],
  );
}
