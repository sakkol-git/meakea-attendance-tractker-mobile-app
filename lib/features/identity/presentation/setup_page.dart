import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/widgets.dart';
import '../../../core/protocol.dart';

class WorkspaceSetupPage extends ConsumerStatefulWidget {
  const WorkspaceSetupPage({super.key});
  @override
  ConsumerState<WorkspaceSetupPage> createState() => _SetupState();
}

class _SetupState extends ConsumerState<WorkspaceSetupPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      slug = TextEditingController(),
      ownerName = TextEditingController(),
      email = TextEditingController(),
      authorization = TextEditingController();
  String key = commandKey();
  String? fingerprint, error;
  bool review = false, busy = false, done = false;
  @override
  void dispose() {
    for (final c in [name, slug, ownerName, email, authorization]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final body = <String, dynamic>{
      'name': name.text.trim(),
      'slug': slug.text.trim(),
      'ownerName': ownerName.text.trim(),
      'ownerEmail': email.text.trim(),
      'bootstrapCode': authorization.text.trim(),
      'timezone': 'Asia/Phnom_Penh',
      'locale': 'en',
    };
    final hash = canonicalJson(body);
    if (hash != fingerprint) {
      key = commandKey();
      fingerprint = hash;
      review = false;
    }
    if (!review) {
      setState(() => review = true);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(identityRepositoryProvider)
          .changeCase('identity.setup', null, body, key: key);
      if (mounted) setState(() => done = true);
    } catch (e) {
      if (mounted) setState(() => error = message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = ref.watch(clientProvider).isLocal;
    return AppPage(
      title: 'Set up a workspace',
      subtitle: local
          ? 'Configure the fictional demo company. No real account or invitation is created.'
          : 'An authorized company setup code is required. Your service controls onboarding and owner invitation.',
      children: [
        if (done) ...[
          const Surface(
            child: Text(
              'Workspace created. Follow the owner invitation supplied by your administrator, then sign in with your company workspace.',
            ),
          ),
          FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Continue to sign in'),
          ),
        ] else
          Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (review) ...[
                  InfoRow('Company', name.text),
                  InfoRow('Workspace', slug.text),
                  InfoRow('Owner', ownerName.text),
                  InfoRow('Owner email', email.text),
                  const Text(
                    'Confirm the company and owner details. Your setup authorization is sent only to the configured service.',
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() => review = false),
                    child: const Text('Revise details'),
                  ),
                ] else ...[
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Company name',
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 3
                        ? 'Enter at least 3 characters'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: slug,
                    decoration: const InputDecoration(
                      labelText: 'Company workspace',
                    ),
                    validator: (v) =>
                        RegExp(r'^[a-z0-9-]{3,50}$').hasMatch(v ?? '')
                        ? null
                        : 'Use 3–50 lowercase letters, numbers or hyphens',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: ownerName,
                    decoration: const InputDecoration(labelText: 'Owner name'),
                    validator: (v) => (v?.trim().length ?? 0) < 3
                        ? 'Enter the owner name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Owner work email',
                    ),
                    validator: (v) =>
                        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v ?? '')
                        ? null
                        : 'Enter a valid work email',
                  ),
                  const SizedBox(height: 16),
                  if (!local)
                    TextFormField(
                      controller: authorization,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Company setup code',
                      ),
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'Enter your authorized setup code'
                          : null,
                    ),
                ],
                const SizedBox(height: 24),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? 'Creating…'
                        : review
                        ? 'Create workspace'
                        : 'Review workspace',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
