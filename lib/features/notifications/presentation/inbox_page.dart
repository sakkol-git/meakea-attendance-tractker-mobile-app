import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/notice_route.dart';

import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});
  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsState();
}

class _NotificationsState extends ConsumerState<NotificationsPage> {
  bool onlyUnread = false, marking = false;
  Future<void> markAll() async {
    if (marking) return;
    setState(() => marking = true);
    try {
      await ref.read(notificationsRepositoryProvider).markRead(null);
      ref.invalidate(inboxProvider);
      if (mounted) toast(context, 'All updates marked read');
    } catch (e) {
      if (mounted) toast(context, message(e));
    } finally {
      if (mounted) setState(() => marking = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Notifications',
    subtitle: 'Review updates about your requests and attendance.',
    actions: [
      TextButton(
        onPressed:
            marking ||
                !(ref
                        .watch(inboxProvider)
                        .asData
                        ?.value
                        .any((row) => !row.read) ??
                    false)
            ? null
            : markAll,
        child: Text(marking ? 'Updating…' : 'Mark all read'),
      ),
    ],
    onRefresh: () async {
      ref.invalidate(inboxProvider);
      await ref.read(inboxProvider.future);
    },
    children: [
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Unread only'),
        value: onlyUnread,
        onChanged: (value) => setState(() => onlyUnread = value),
      ),
      AsyncPanel(
        value: ref.watch(inboxProvider),
        retry: () => ref.invalidate(inboxProvider),
        builder: (all) {
          final rows = all.where((row) => !onlyUnread || !row.read).toList();
          return rows.isEmpty
              ? EmptyState(
                  title: onlyUnread ? 'No unread updates' : 'All quiet for now',
                  description: onlyUnread
                      ? 'You can still review updates you have already read.'
                      : 'Updates about your requests and attendance will appear here.',
                  icon: Icons.notifications_none,
                  action: onlyUnread
                      ? TextButton(
                          onPressed: () => setState(() => onlyUnread = false),
                          child: const Text('Show all updates'),
                        )
                      : null,
                )
              : Column(
                  children: [
                    for (final m in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Icon(
                              m.read
                                  ? Icons.notifications_none
                                  : Icons.notifications_active_outlined,
                              color: m.read
                                  ? context.semantic.textMuted
                                  : context.semantic.selectedNav,
                            ),
                            title: Text(
                              m.title,
                              style: TextStyle(
                                fontWeight: m.read
                                    ? FontWeight.w400
                                    : FontWeight.w600,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.body),
                                  const SizedBox(height: 8),
                                  Text(
                                    m.read ? 'Read' : 'Unread',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium,
                                  ),
                                  if (notificationRecordPath({
                                        'kind': m.kind,
                                        'recordId': m.recordId,
                                      }) ==
                                      null)
                                    const Text(
                                      'No linked record is available for this update.',
                                    ),
                                ],
                              ),
                            ),
                            trailing: m.read
                                ? null
                                : Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: context.semantic.selectedNav,
                                  ),
                            onTap: () async {
                              try {
                                if (!m.read) {
                                  await ref
                                      .read(notificationsRepositoryProvider)
                                      .markRead(m.id);
                                  ref.invalidate(inboxProvider);
                                }
                                final path = notificationRecordPath({
                                  'kind': m.kind,
                                  'recordId': m.recordId,
                                });
                                if (context.mounted && path != null) {
                                  context.push(path);
                                }
                              } catch (e) {
                                if (context.mounted) toast(context, message(e));
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                );
        },
      ),
    ],
  );
}
