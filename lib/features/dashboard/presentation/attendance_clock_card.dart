import 'package:flutter/material.dart';

import 'package:hrflow_mobile/core/design_tokens.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/features/attendance/domain/models.dart';

class AttendanceClockCard extends StatelessWidget {
  const AttendanceClockCard({
    super.key,
    required AttendanceDay this.day,
    required Future<void> Function(WorkSession?) this.record,
  });
  const AttendanceClockCard.loading({super.key}) : day = null, record = null;

  final AttendanceDay? day;
  final Future<void> Function(WorkSession? open)? record;

  @override
  Widget build(BuildContext context) {
    final colors = context.semantic;
    final theme = Theme.of(context);
    final loading = day == null;
    final sessions = day?.sessions;
    final open = sessions
        ?.where((session) => session.clockOut == null)
        .firstOrNull;
    DateTime? lastIn, lastOut;
    for (final session in sessions ?? const <WorkSession>[]) {
      if (lastIn == null || session.clockIn.isAfter(lastIn)) {
        lastIn = session.clockIn;
      }
      final end = session.clockOut;
      if (end != null && (lastOut == null || end.isAfter(lastOut))) {
        lastOut = end;
      }
    }
    final secondary = MediaQuery.highContrastOf(context)
        ? colors.onHero
        : colors.onHeroMuted;
    final status = open != null
        ? 'Clocked in'
        : lastIn != null
        ? 'Clocked out'
        : 'Not clocked in';
    final action = open == null ? 'Clock in' : 'Clock out';
    final metrics = [
      _ClockMetric('Last clock-in', timeText(lastIn), secondary: secondary),
      _ClockMetric('Last clock-out', timeText(lastOut), secondary: secondary),
    ];
    return Semantics(
      container: true,
      liveRegion: loading,
      label: loading ? 'Loading today’s attendance' : null,
      excludeSemantics: loading,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.heroBackground,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule_outlined, color: secondary),
                  const SizedBox(width: AppSpacing.x2),
                  Expanded(
                    child: Text(
                      'Today’s attendance',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),
              _ClockSlot(
                loading: loading,
                child: Text(
                  status,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colors.onHero,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              _ClockSlot(
                loading: loading,
                child: Theme(
                  data: theme.copyWith(
                    filledButtonTheme: FilledButtonThemeData(
                      style: FilledButton.styleFrom(
                        foregroundColor: colors.heroBackground,
                        backgroundColor: colors.onHero,
                        minimumSize: const Size(
                          AppSize.minTouchTarget,
                          AppSize.primaryControl,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                      ),
                    ),
                  ),
                  child: BusyButton(
                    label: action,
                    icon: open == null ? Icons.login : Icons.logout,
                    enabled: !loading,
                    action: () => record!(open),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              _ClockSlot(
                loading: loading,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final largeText =
                        MediaQuery.textScalerOf(context).scale(1) >= 2;
                    if (largeText &&
                        constraints.maxWidth < AppSize.tabletBreakpoint) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          metrics.first,
                          const SizedBox(height: AppSpacing.x2),
                          metrics.last,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: metrics.first),
                        const SizedBox(width: AppSpacing.x4),
                        Expanded(child: metrics.last),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                'Times shown in GMT+07',
                style: theme.textTheme.bodySmall?.copyWith(color: secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClockSlot extends StatelessWidget {
  const _ClockSlot({required this.loading, required this.child});
  final bool loading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!loading) return child;
    // Keep the actual control's footprint while the attendance query is pending.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.semantic.heroSubtle,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Visibility.maintain(visible: false, child: child),
    );
  }
}

class _ClockMetric extends StatelessWidget {
  const _ClockMetric(this.label, this.value, {required this.secondary});
  final String label, value;
  final Color secondary;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: secondary),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: context.semantic.onHero),
        ),
      ],
    ),
  );
}
