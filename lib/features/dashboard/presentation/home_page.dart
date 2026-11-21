import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/leave_quantity.dart';

import 'package:hrflow_mobile/core/design_tokens.dart';

import 'attendance_clock_card.dart';
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
        const SizedBox(width: AppSpacing.x2),
      ],
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.large),
          onTap: () => context.push('/profile'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
            child: Row(
              children: [
                CircleAvatar(
                  radius: AppSpacing.x6,
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
                const SizedBox(width: AppSpacing.x4),
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
        const SizedBox(height: AppSpacing.x3),
        AsyncPanel(
          value: today,
          retry: () => ref.invalidate(todayProvider),
          loadingBuilder: (_) => const AttendanceClockCard.loading(),
          builder: (day) => AttendanceClockCard(
            day: day,
            record: (open) async {
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
                  open == null ? 'Clock-in recorded' : 'Clock-out recorded',
                );
              }
            },
          ),
        ),
        const SectionTitle('Quick actions'),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - AppSpacing.x3) / 2;
            return Wrap(
              spacing: AppSpacing.x3,
              runSpacing: AppSpacing.x3,
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
          builder: (balances) => balances.isEmpty
              ? Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No leave balances available',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton(
                        onPressed: () => context.push('/leave'),
                        child: const Text('View leave'),
                      ),
                    ],
                  ),
                )
              : Surface(
                  child: Column(
                    children: [
                      for (var i = 0; i < balances.length; i++) ...[
                        if (i > 0) const Divider(height: AppSpacing.x6),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(balances[i].name),
                                  Text(
                                    leaveBalancePeriod(balances[i].year),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
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
        const SizedBox(height: AppSpacing.x4),
        Surface(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                color: context.semantic.selectedNav,
              ),
              SizedBox(width: AppSpacing.x3),
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
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: c.semantic.selectedNav),
              const SizedBox(height: AppSpacing.x4),
              Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.x1),
              Text(
                subtitle,
                style: Theme.of(c).textTheme.bodySmall
                    ?.copyWith(color: c.semantic.textMuted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
