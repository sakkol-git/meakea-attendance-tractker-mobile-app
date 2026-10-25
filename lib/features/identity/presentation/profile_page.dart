import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(sessionProvider).profile!;
    final local = ref.watch(clientProvider).isLocal;
    return AppPage(
      title: 'Personal profile',
      children: [
        Surface(
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: context.semantic.successBackground,
                child: Text(
                  p.name.split(' ').map((s) => s[0]).take(2).join(),
                  style: TextStyle(
                    color: context.semantic.selectedNav,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(p.name, style: Theme.of(context).textTheme.headlineMedium),
              Text(
                p.position,
                style: TextStyle(color: context.semantic.textMuted),
              ),
              const SizedBox(height: 12),
              StatusPill(p.role),
              const SizedBox(height: 16),
              InfoRow('Company', p.organization),
              InfoRow('Department', p.department),
              InfoRow('Email', p.email),
            ],
          ),
        ),
        const SectionTitle('Account settings'),
        _Link(Icons.person_outline, 'Personal information', '/profile/edit'),
        _Link(Icons.shield_outlined, 'Security & device lock', '/security'),
        _Link(Icons.tune_outlined, 'Preferences', '/preferences'),
        const SectionTitle('About HRFlow'),
        _Link(Icons.info_outline, 'About this workspace', '/about'),
        if (local) ...[
          const SectionTitle('Demo workspace'),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Switch personas to follow a request from submission through approval. Demo changes stay on this device.',
                  style: TextStyle(color: context.semantic.textMuted),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  itemHeight: null,
                  initialValue: p.role,
                  decoration: const InputDecoration(labelText: 'Demo role'),
                  items: const [
                    DropdownMenuItem(
                      value: 'EMPLOYEE',
                      child: Text('Employee · Sok Dara'),
                    ),
                    DropdownMenuItem(
                      value: 'MANAGER',
                      child: Text('Manager · Chan Sopheak'),
                    ),
                    DropdownMenuItem(
                      value: 'HR_ADMIN',
                      child: Text('HR · Kim Sreyneang'),
                    ),
                    DropdownMenuItem(
                      value: 'OWNER',
                      child: Text('Owner · Vann Rith'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) ref.read(sessionProvider.notifier).demo(v);
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    final reset = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text('Reset demo workspace?'),
                        content: Text(
                          'All demo changes, files and decisions will be cleared.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: Text('Keep data'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: Text('Reset'),
                          ),
                        ],
                      ),
                    );
                    if (reset == true) {
                      await ref.read(clientProvider).resetDemo();
                      await ref.read(sessionProvider.notifier).demo('EMPLOYEE');
                      if (context.mounted) {
                        toast(context, 'Demo workspace reset');
                      }
                    }
                  },
                  child: Text('Reset demo data'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text('Sign out?'),
                content: Text(
                  'Your workspace data remains saved. You can sign in again at any time.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: Text('Stay here'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: Text('Sign out'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await ref.read(sessionProvider.notifier).signOut();
            }
          },
          icon: Icon(Icons.logout),
          label: Text('Sign out'),
        ),
      ],
    );
  }
}

class _Link extends StatelessWidget {
  final IconData icon;
  final String title, path;
  const _Link(this.icon, this.title, this.path);
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
        leading: Icon(icon, color: c.semantic.selectedNav),
        title: Text(title),
        trailing: Icon(Icons.chevron_right),
        onTap: () => c.push(path),
      ),
    ),
  );
}

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});
  @override
  ConsumerState<EditProfilePage> createState() => _EditProfileState();
}

class _EditProfileState extends ConsumerState<EditProfilePage> {
  final form = GlobalKey<FormState>();
  late TextEditingController name, phone;
  @override
  void initState() {
    super.initState();
    final p = ref.read(sessionProvider).profile!;
    name = TextEditingController(text: p.name);
    phone = TextEditingController(text: p.phone);
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Personal information',
    subtitle: 'Keep your contact details up to date.',
    children: [
      Surface(
        child: Form(
          key: form,
          child: Column(
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Full name'),
                autofillHints: const [AutofillHints.name],
                validator: (v) =>
                    (v?.trim().length ?? 0) < 2 ? 'Enter your name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Phone number'),
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: (v) =>
                    v != null &&
                        v.isNotEmpty &&
                        !RegExp(r'^\+?[0-9 ()-]{7,20}$').hasMatch(v)
                    ? 'Enter a valid phone number'
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                'Your work email, position and department are managed by HR.',
                style: TextStyle(color: context.semantic.textMuted),
              ),
              const SizedBox(height: 24),
              BusyButton(
                label: 'Save changes',
                icon: Icons.check,
                action: () async {
                  if (!form.currentState!.validate()) return;
                  final profile = await ref
                      .read(identityRepositoryProvider)
                      .saveProfile({
                        'name': name.text.trim(),
                        'phone': phone.text.trim(),
                      });
                  ref.read(sessionProvider.notifier).updateProfile(profile);
                  if (context.mounted) {
                    toast(context, 'Profile updated');
                    context.pop();
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
