import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/widgets.dart';

class NotificationPreferencesPanel extends ConsumerStatefulWidget {
  const NotificationPreferencesPanel({super.key});
  @override
  ConsumerState<NotificationPreferencesPanel> createState() =>
      _PreferencesState();
}

class _PreferencesState extends ConsumerState<NotificationPreferencesPanel> {
  bool saving = false;

  @override
  Widget build(BuildContext context) {
    final local = ref.watch(clientProvider).isLocal;
    final fields = local
        ? [
            ('attendance', 'Attendance reminders'),
            ('announcements', 'Company announcements'),
          ]
        : [
            ('email', 'Email notifications'),
            ('inApp', 'In-app notifications'),
            ('reminders', 'Reminders'),
          ];
    return AsyncPanel(
      value: ref.watch(notificationPreferencesProvider),
      retry: () => ref.invalidate(notificationPreferencesProvider),
      builder: (settings) => Surface(
        child: Column(
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Approval updates'),
              subtitle: Text(
                'Required approval updates stay in your inbox, even when optional updates are off.',
              ),
              trailing: Icon(Icons.lock_outline, size: 20),
            ),
            for (final (key, label) in fields)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(label),
                value: settings.values[key]!,
                onChanged: saving
                    ? null
                    : (value) async {
                        setState(() => saving = true);
                        try {
                          await ref
                              .read(notificationsRepositoryProvider)
                              .savePreferences(settings.withValue(key, value));
                          ref.invalidate(notificationPreferencesProvider);
                        } catch (error) {
                          if (context.mounted) toast(context, message(error));
                        } finally {
                          if (mounted) setState(() => saving = false);
                        }
                      },
              ),
          ],
        ),
      ),
    );
  }
}
