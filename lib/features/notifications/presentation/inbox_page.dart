import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: 'Notifications',
    subtitle: 'Stay in the loop, without the noise.',
    actions: [
      TextButton(
        onPressed: () async {
          try {
            await ref.read(notificationsRepositoryProvider).markRead(null);
            ref.invalidate(inboxProvider);
          } catch (e) {
            if (context.mounted) toast(context, message(e));
          }
        },
        child: Text('Read all'),
      ),
    ],
    onRefresh: () async {
      ref.invalidate(inboxProvider);
      await ref.read(inboxProvider.future);
    },
    children: [
      AsyncPanel(
        value: ref.watch(inboxProvider),
        retry: () => ref.invalidate(inboxProvider),
        builder: (rows) => rows.isEmpty
            ? const EmptyState(
                title: 'All quiet for now',
                description: 'Updates about your requests and attendance will appear here.',
                icon: Icons.notifications_none,
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
                            child: Text(m.body),
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
                              if (context.mounted &&
                                  m.recordId != null &&
                                  m.kind != null) {
                                context.push('/record/${m.kind}/${m.recordId}');
                              }
                            } catch (e) {
                              if (context.mounted) toast(context, message(e));
                            }
                          },
                        ),
                      ),
                    ),
                ],
              ),
      ),
    ],
  );
}
