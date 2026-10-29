import 'package:flutter/material.dart';

import '../../../core/widgets.dart';

class FormReview extends StatelessWidget {
  final List<(String, String)> rows;
  final String nextStep;
  const FormReview({super.key, required this.rows, required this.nextStep});
  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 16),
    title: const Text('Review details'),
    children: [for (final row in rows) InfoRow(row.$1, row.$2), Text(nextStep)],
  );
}
