import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme.dart';
import '../../../core/widgets.dart';
import '../../attendance/domain/correction_time.dart';

class WorkflowDateFields extends ConsumerWidget {
  final String kind, requestType, portion;
  final DateTime from, to;
  final TimeOfDay start, end;
  final bool halfDayAllowed, saving;
  final ValueChanged<bool> pickDate, pickTime;
  final ValueChanged<String> changePortion;
  const WorkflowDateFields({
    super.key,
    required this.kind,
    required this.requestType,
    required this.portion,
    required this.from,
    required this.to,
    required this.start,
    required this.end,
    required this.halfDayAllowed,
    required this.saving,
    required this.pickDate,
    required this.pickTime,
    required this.changePortion,
  });
  String day(DateTime value) => value.toIso8601String().substring(0, 10);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leave = kind == 'leave', correction = kind == 'correction';
    if (!leave &&
        !correction &&
        ['GENERAL', 'MATERIAL'].contains(requestType)) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text(
          correction ? 'Corrected dates and times' : 'Dates and time',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _DateButton(
          label: correction ? 'Correct clock-in date' : 'From',
          value: shortDate(day(from)),
          icon: Icons.calendar_today_outlined,
          onTap: saving ? null : () => pickDate(true),
        ),
        if (leave || correction || requestType == 'REMOTE_WORK') ...[
          const SizedBox(height: 12),
          _DateButton(
            label: correction ? 'Correct clock-out date' : 'To',
            value: shortDate(day(to)),
            icon: Icons.calendar_today_outlined,
            onTap: saving ? null : () => pickDate(false),
          ),
        ],
        if (leave && halfDayAllowed) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            isExpanded: true,
            itemHeight: null,
            initialValue: portion,
            decoration: const InputDecoration(labelText: 'Day portion'),
            items: const [
              DropdownMenuItem(value: 'FULL_DAY', child: Text('Full day')),
              DropdownMenuItem(value: 'MORNING', child: Text('Morning only')),
              DropdownMenuItem(
                value: 'AFTERNOON',
                child: Text('Afternoon only'),
              ),
            ],
            onChanged: saving
                ? null
                : (value) {
                    if (value != null) changePortion(value);
                  },
          ),
          const SizedBox(height: 12),
          Text(
            'Half-day leave uses one date. Submit separate requests for different calendar years. The preview uses your assigned schedule and company holidays.',
            style: TextStyle(fontSize: 12, color: context.semantic.textMuted),
          ),
        ],
        if (correction ||
            ['LATE_ARRIVAL', 'EARLY_LEAVE'].contains(requestType)) ...[
          const SizedBox(height: 16),
          _DateButton(
            label: correction ? 'Correct clock-in time' : 'From time',
            value: start.format(context),
            icon: Icons.schedule_outlined,
            onTap: saving ? null : () => pickTime(true),
          ),
          const SizedBox(height: 12),
          _DateButton(
            label: correction ? 'Correct clock-out time' : 'To time',
            value: end.format(context),
            icon: Icons.schedule_outlined,
            onTap: saving ? null : () => pickTime(false),
          ),
        ],
        if (correction) ...[
          const SizedBox(height: 12),
          const Text('Company time zone: Asia/Phnom_Penh (UTC+07)'),
          if (day(to) != day(from))
            const Text('Ends next day', key: Key('correction-next-day')),
          const SizedBox(height: 12),
          const Text('Original recorded time'),
          AsyncPanel(
            value: ref.watch(sessionsProvider),
            retry: () => ref.invalidate(sessionsProvider),
            builder: (sessions) {
              final originals = sessions
                  .where(
                    (session) =>
                        day(
                          session.clockIn.toUtc().add(
                            CorrectionTime.companyOffset,
                          ),
                        ) ==
                        day(from),
                  )
                  .toList();
              if (originals.isEmpty) {
                return const Text('No recorded session on this date');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final session in originals)
                    Text(
                      '${CorrectionTime.display(session.clockIn)} → ${CorrectionTime.display(session.clockOut)}',
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Proposed: ${CorrectionTime.display(CorrectionTime.instant(from, start.hour, start.minute))} → ${CorrectionTime.display(CorrectionTime.instant(to, end.hour, end.minute))}',
          ),
        ],
      ],
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final VoidCallback? onTap;
  const _DateButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.centerLeft,
    ),
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: context.semantic.textMuted,
                ),
              ),
              Text(value, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    ),
  );
}
