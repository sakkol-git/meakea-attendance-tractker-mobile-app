import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/leave_quantity.dart';

import 'role_tasks.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String? clockKey;
  @override
  Widget build(BuildContext context) {
    final p = ref.watch(sessionProvider).profile!;
    final today = ref.watch(todayProvider);
    final inbox = ref.watch(inboxProvider).asData?.value ?? [];
    return AppPage(
      title: 'Your workday',
      subtitle: DateFormat('EEEE, d MMMM').format(ref.read(clockProvider)()),
      onRefresh: () async {
        ref.invalidate(todayProvider);
        ref.invalidate(sessionsProvider);
        ref.invalidate(inboxProvider);
        await ref.read(todayProvider.future);
      },
      actions: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => context.push('/notifications'),
          icon: Badge(
            isLabelVisible: inbox.any((m) => !m.read),
            child: Icon(Icons.notifications_outlined),
          ),
        ),
        IconButton(
          tooltip: 'Personal profile',
          onPressed: () => context.push('/profile'),
          icon: const Icon(Icons.person_outline),
        ),
        const SizedBox(width: 8),
      ],
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/profile'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: context.semantic.successBackground,
                  child: Text(
                    p.name
                        .split(' ')
                        .where((s) => s.isNotEmpty)
                        .map((s) => s[0])
                        .take(2)
                        .join(),
                    style: TextStyle(
                      color: context.semantic.selectedNav,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${p.name.split(' ').first}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(
                        p.position,
                        style: TextStyle(color: context.semantic.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.semantic.textMuted),
              ],
            ),
          ),
        ),
        RoleTasks(p),
        const SizedBox(height: 12),
        AsyncPanel(
          value: today,
          retry: () => ref.invalidate(todayProvider),
          builder: (data) {
            final sessions = data.sessions;
            final open = sessions.where((s) => s.clockOut == null).firstOrNull;
            final recent = sessions.lastOrNull;
            return Container(
              padding: EdgeInsets.all(p.manages ? 16 : 24),
              decoration: BoxDecoration(
                color: context.semantic.heroBackground,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        color: context.semantic.onHeroMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          open == null
                              ? 'Make today count'
                              : 'You’re clocked in',
                          style: TextStyle(
                            color: context.semantic.onHero,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: open == null
                              ? context.semantic.heroSubtle
                              : context.semantic.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: p.manages ? 10 : 20),
                  Text(
                    p.manages
                        ? 'Your attendance'
                        : open == null
                        ? (recent == null
                              ? 'Ready for a\nproductive day?'
                              : 'Your workday,\nwell recorded.')
                        : 'One task at\na time.',
                    style: TextStyle(
                      color: context.semantic.onHero,
                      fontSize: p.manages ? 20 : 30,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: p.manages ? 12 : 24),
                  Row(
                    children: [
                      Expanded(
                        child: _ClockMetric(
                          'Clock in',
                          timeText((open ?? recent)?.clockIn),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 38,
                        color: context.semantic.heroSubtle,
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _ClockMetric(
                          'Clock out',
                          timeText(recent?.clockOut),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: p.manages ? 12 : 24),
                  Theme(
                    data: Theme.of(context).copyWith(
                      filledButtonTheme: FilledButtonThemeData(
                        style: FilledButton.styleFrom(
                          backgroundColor: context.semantic.onHero,
                          foregroundColor: context.semantic.heroBackground,
                          minimumSize: const Size(48, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    child: BusyButton(
                      label: open == null ? 'Clock in' : 'Clock out',
                      icon: open == null ? Icons.login : Icons.logout,
                      action: () async {
                        clockKey ??= commandKey();
                        await ref
                            .read(attendanceRepositoryProvider)
                            .clock(open: open, key: clockKey!);
                        clockKey = null;
                        ref.invalidate(todayProvider);
                        ref.invalidate(sessionsProvider);
                        if (context.mounted) {
                          toast(
                            context,
                            open == null
                                ? 'Clock-in recorded'
                                : 'Clock-out recorded',
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Recorded in your company timezone · GMT+07',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.semantic.onHeroMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SectionTitle('Quick actions'),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QuickAction(
                  width: width,
                  title: 'Request leave',
                  subtitle: 'Choose dates and review your balance',
                  icon: Icons.beach_access_outlined,
                  onTap: () => context.push('/new/leave'),
                ),
                _QuickAction(
                  width: width,
                  title: 'New request',
                  subtitle: 'Get what you need',
                  icon: Icons.add_task_outlined,
                  onTap: () => context.push('/new/request'),
                ),
                _QuickAction(
                  width: width,
                  title: 'Attendance correction',
                  subtitle: 'Keep time accurate',
                  icon: Icons.edit_calendar_outlined,
                  onTap: () => context.push('/new/correction'),
                ),
                _QuickAction(
                  width: width,
                  title: p.manages ? 'Approvals' : 'My schedule',
                  subtitle: p.manages
                      ? 'Keep your team moving'
                      : 'Plan the week ahead',
                  icon: p.manages
                      ? Icons.fact_check_outlined
                      : Icons.calendar_month_outlined,
                  onTap: () =>
                      context.push(p.manages ? '/approvals' : '/schedule'),
                ),
              ],
            );
          },
        ),
        const SectionTitle('Leave balances'),
        AsyncPanel(
          value: ref.watch(balancesProvider),
          retry: () => ref.invalidate(balancesProvider),
          builder: (balances) => Surface(
            child: Column(
              children: [
                for (var i = 0; i < balances.length; i++) ...[
                  if (i > 0) const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(balances[i].name),
                            Text(
                              leaveBalancePeriod(balances[i].year),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatLeaveDays(balances[i].available),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: context.semantic.selectedNav,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Surface(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                color: context.semantic.selectedNav,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Small habits, better workdays. Remember to clock out when you finish.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClockMetric extends StatelessWidget {
  final String label, value;
  const _ClockMetric(this.label, this.value);
  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(color: c.semantic.onHeroMuted, fontSize: 12),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: TextStyle(
          color: c.semantic.onHero,
          fontSize: value == 'Not recorded' ? 16 : 24,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _QuickAction extends StatelessWidget {
  final double width;
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _QuickAction({
    required this.width,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext c) => SizedBox(
    width: width,
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: c.semantic.selectedNav),
              const SizedBox(height: 16),
              Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: c.semantic.textMuted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
