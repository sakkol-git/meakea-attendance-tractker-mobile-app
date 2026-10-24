import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final form = GlobalKey<FormState>();
  final tenant = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  bool obscure = true;
  @override
  void dispose() {
    tenant.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final local = ref.watch(clientProvider).isLocal;
    final session = ref.watch(sessionProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(28),
              children: [
                const SizedBox(height: 40),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: context.semantic.heroBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.layers_outlined,
                        color: context.semantic.onHero,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'hrflow',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 56),
                Text(
                  local ? 'A better workday\nstarts here.' : 'Welcome back.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  local
                      ? 'Explore your workspace with fictional data. Choose a role to walk through the experience.'
                      : 'Sign in to your company workspace to manage your day.',
                  style: TextStyle(color: context.semantic.textMuted),
                ),
                const SizedBox(height: 32),
                if (session.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      session.error!,
                      style: TextStyle(color: context.semantic.error),
                    ),
                  ),
                if (local) ...demoChoices() else remoteForm(),
                TextButton(
                  onPressed: () => context.push('/setup'),
                  child: Text('Set up a company workspace'),
                ),
                const SizedBox(height: 40),
                Text(
                  'Your people. Your workspace.\nDesigned for a calmer workday.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.semantic.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> demoChoices() => [
    const StatusPill('DEMO WORKSPACE'),
    const SizedBox(height: 20),
    for (final entry in [
      (
        'EMPLOYEE',
        'Employee',
        'My attendance, leave and requests',
        Icons.person_outline,
      ),
      (
        'MANAGER',
        'Manager',
        'Team activity and approvals',
        Icons.groups_outlined,
      ),
      (
        'HR_ADMIN',
        'HR administrator',
        'People, policies and reporting',
        Icons.badge_outlined,
      ),
      (
        'OWNER',
        'Company owner',
        'Organization overview',
        Icons.business_outlined,
      ),
    ])
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Surface(
          padding: EdgeInsets.zero,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Icon(entry.$4, color: context.semantic.selectedNav),
            title: Text(
              entry.$2,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(entry.$3),
            trailing: Icon(Icons.arrow_forward, size: 20),
            onTap: () => ref.read(sessionProvider.notifier).demo(entry.$1),
          ),
        ),
      ),
  ];
  Widget remoteForm() => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: tenant,
          decoration: const InputDecoration(labelText: 'Company workspace'),
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.organizationName],
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Enter your workspace' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: email,
          decoration: const InputDecoration(labelText: 'Work email'),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username],
          textInputAction: TextInputAction.next,
          validator: (v) =>
              v == null || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)
              ? 'Enter a valid email'
              : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: password,
          obscureText: obscure,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: 'Password',
            suffixIcon: IconButton(
              tooltip: obscure ? 'Show password' : 'Hide password',
              onPressed: () => setState(() => obscure = !obscure),
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: (v) =>
              v == null || v.isEmpty ? 'Enter your password' : null,
        ),
        const SizedBox(height: 24),
        BusyButton(
          label: 'Sign in',
          icon: Icons.login,
          action: () async {
            if (form.currentState!.validate()) {
              await ref
                  .read(sessionProvider.notifier)
                  .signIn(tenant.text.trim(), email.text.trim(), password.text);
            }
          },
        ),
        TextButton(
          child: Text('Need help signing in?'),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text('Need help signing in?'),
              content: Text(
                'Contact your company HR administrator to reset your account access.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: Text('Got it'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class LockPage extends ConsumerWidget {
  const LockPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppPage(
    title: 'Workspace locked',
    children: [
      const SizedBox(height: 64),
      Icon(Icons.lock_outline, size: 64, color: context.semantic.selectedNav),
      const SizedBox(height: 24),
      Text(
        'Welcome back',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      Text(
        'Use your device biometrics or passcode to unlock your workspace.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 32),
      BusyButton(
        label: 'Unlock workspace',
        icon: Icons.fingerprint,
        action: () async {
          final allowed = await LocalAuthentication().authenticate(
            localizedReason: 'Unlock your HRFlow workspace',
            persistAcrossBackgrounding: true,
          );
          if (allowed) ref.read(sessionProvider.notifier).unlock();
        },
      ),
      TextButton(
        onPressed: () => ref.read(sessionProvider.notifier).signOut(),
        child: Text('Sign out instead'),
      ),
    ],
  );
}
