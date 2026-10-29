import 'package:flutter/material.dart';

import '../../../core/widgets.dart';
import '../domain/correction_time.dart';

/// Missing historical evidence differs from an authoritative empty snapshot.
class CorrectionOriginalTimes extends StatelessWidget {
  final List<dynamic>? sessions;
  const CorrectionOriginalTimes({super.key, this.sessions});
  @override
  Widget build(BuildContext context) {
    if (sessions == null) {
      return const InfoRow(
        'Original',
        'Original session snapshot is not available.',
      );
    }
    if (sessions!.isEmpty) {
      return const InfoRow('Original', 'No recorded session');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final raw in sessions!)
          Builder(
            builder: (context) {
              final session = Map<String, dynamic>.from(raw as Map);
              return InfoRow(
                'Original',
                '${CorrectionTime.display(DateTime.tryParse((session['checkInAt'] ?? session['clockIn'] ?? '').toString()))} → ${CorrectionTime.display(DateTime.tryParse((session['checkOutAt'] ?? session['clockOut'] ?? '').toString()))}',
              );
            },
          ),
      ],
    );
  }
}
