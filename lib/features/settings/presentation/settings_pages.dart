import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';

class PreferencesPage extends ConsumerWidget {
  const PreferencesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return AppPage(
      title: 'Preferences',
      children: [
        Surface(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dark appearance'),
                subtitle: const Text('A softer workspace in low light'),
                value: settings.dark,
                onChanged: ref.read(settingsProvider.notifier).setDark,
              ),
              const Divider(height: 24),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Language'),
                subtitle: Text('English · Khmer typography supported'),
              ),
            ],
          ),
        ),
        const SectionTitle('Notifications'),
        AsyncPanel(
          value: ref.watch(notificationPreferencesProvider),
          retry: () => ref.invalidate(notificationPreferencesProvider),
          builder: (values) => Surface(
            child: Column(
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Approval updates'),
                  subtitle: Text('Required updates about your requests'),
                  trailing: Icon(Icons.lock_outline, size: 20),
                ),
                for (final entry in [
                  ('attendance', 'Attendance reminders'),
                  ('announcements', 'Company announcements'),
                ])
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.$2),
                    value: values[entry.$1] as bool? ?? true,
                    onChanged: (v) async {
                      try {
                        await ref
                            .read(notificationsRepositoryProvider)
                            .savePreferences({
                              ...values,
                              entry.$1: v,
                              'approvals': true,
                            });
                        ref.invalidate(notificationPreferencesProvider);
                      } catch (e) {
                        if (context.mounted) toast(context, message(e));
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SecurityPage extends ConsumerWidget {
  const SecurityPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(settingsProvider).deviceLock;
    final local = ref.watch(clientProvider).isLocal;
    return AppPage(
      title: 'Security',
      subtitle: 'A little extra protection for your workspace.',
      children: [
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 48,
                color: Palette.teal,
              ),
              const SizedBox(height: 16),
              Text(
                'Your device. Your access.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Use your device biometrics or passcode when returning to HRFlow. Your device handles verification; HRFlow never stores your device PIN.',
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require device unlock'),
                value: enabled,
                onChanged: kIsWeb
                    ? null
                    : (v) async {
                        try {
                          final auth = LocalAuthentication();
                          if (!await auth.isDeviceSupported()) {
                            if (context.mounted) {
                              toast(
                                context,
                                'Set up a device passcode or biometrics first.',
                              );
                            }
                            return;
                          }
                          if (await auth.authenticate(
                            localizedReason:
                                'Change your HRFlow device lock setting',
                          )) {
                            await ref
                                .read(settingsProvider.notifier)
                                .setLock(v);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            toast(
                              context,
                              'Device authentication is unavailable. Check your device security settings.',
                            );
                          }
                        }
                      },
              ),
              if (kIsWeb)
                const Text(
                  'Device unlock is available in the native Android and iOS app.',
                  style: TextStyle(color: Palette.muted),
                ),
              if (enabled)
                OutlinedButton.icon(
                  onPressed: () => ref.read(sessionProvider.notifier).lock(),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Lock now'),
                ),
            ],
          ),
        ),
        if (!local) ...[
          const SectionTitle('Account password'),
          OutlinedButton.icon(
            onPressed: () => context.push('/security/password'),
            icon: const Icon(Icons.password),
            label: const Text('Change password'),
          ),
        ],
      ],
    );
  }
}

class PasswordPage extends ConsumerStatefulWidget {
  const PasswordPage({super.key});
  @override
  ConsumerState<PasswordPage> createState() => _PasswordState();
}

class _PasswordState extends ConsumerState<PasswordPage> {
  final form = GlobalKey<FormState>();
  final current = TextEditingController(),
      next = TextEditingController(),
      confirm = TextEditingController();
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Change password',
    children: [
      Surface(
        child: Form(
          key: form,
          child: Column(
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Enter your current password'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (v) =>
                    (v?.length ?? 0) < 12 ? 'Use at least 12 characters' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                validator: (v) =>
                    v != next.text ? 'The passwords do not match' : null,
              ),
              const SizedBox(height: 24),
              BusyButton(
                label: 'Update password',
                action: () async {
                  if (!form.currentState!.validate()) return;
                  await ref
                      .read(identityRepositoryProvider)
                      .command(
                        '/auth/change-password',
                        body: {
                          'currentPassword': current.text,
                          'newPassword': next.text,
                        },
                      );
                  if (context.mounted) {
                    toast(context, 'Password updated. Sign in again.');
                    await ref.read(sessionProvider.notifier).signOut();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext c) => AppPage(
    title: 'About your workspace',
    children: [
      const Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.layers_outlined, size: 40, color: Palette.teal),
            SizedBox(height: 16),
            Text(
              'HRFlow',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'A calmer way to manage your workday. Attendance, leave and requests in one thoughtful workspace.',
            ),
            SizedBox(height: 16),
            Text('Version 1.0.0', style: TextStyle(color: Palette.muted)),
          ],
        ),
      ),
      const SectionTitle('Your information'),
      const Surface(
        child: Text(
          'Your organization manages access to employment records. Contact your HR administrator for your company’s privacy notice, employment policies, data requests or account support.',
        ),
      ),
      const SizedBox(height: 20),
      OutlinedButton(
        onPressed: () => showLicensePage(
          context: c,
          applicationName: 'HRFlow',
          applicationVersion: '1.0.0',
        ),
        child: const Text('Open-source licenses'),
      ),
    ],
  );
}
