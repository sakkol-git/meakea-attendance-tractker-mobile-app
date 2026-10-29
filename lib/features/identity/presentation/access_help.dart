import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets.dart';

class AccessHelp extends StatelessWidget {
  const AccessHelp({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ask HR for your company workspace, linked account and sign-in instructions.',
            ),
            SizedBox(height: 12),
            Text(
              'If you need an account or a new password, contact your HR administrator. Workspace creation and email password recovery are not available here yet.',
            ),
          ],
        ),
      ),
      TextButton(
        onPressed: () => context.push('/help'),
        child: const Text('Sign-in and getting started help'),
      ),
      OutlinedButton(
        onPressed: () => context.go('/login'),
        child: const Text('Back to sign in'),
      ),
    ],
  );
}

class GettingStartedPage extends StatelessWidget {
  const GettingStartedPage({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Help and getting started',
    children: [
      for (final topic in const [
        (
          'What is my workspace?',
          'Your workspace is the company name or code supplied by HR, such as example-company. Enter it separately from your work email. Ask HR if you are unsure.',
        ),
        (
          'Getting an account or a new password',
          'Ask your HR administrator to confirm your account and provide sign-in instructions. Workspace creation and email password recovery are not available in this workspace yet. Never share your password.',
        ),
        (
          'Your first workday',
          'Start on Home to clock in or out. Open Leave to check balances and request dates. Open Requests to save a workplace request draft, review it and then send it for approval. Managers can review decisions in Approvals.',
        ),
        (
          'Location access',
          'Share location only when you are ready. If access was denied, enable location for HRFlow in your browser or device settings and try again. A location estimate does not confirm attendance; your company rules are checked when you submit.',
        ),
        (
          'An action was not confirmed',
          'Keep your entries and check the record or attendance history before trying again. An interrupted connection can leave the result unknown. If the status is still unclear, contact HR and include the support reference shown with the error.',
        ),
        (
          'Drafts and unsaved entries',
          'A saved workplace request draft is different from unsaved form entries. Follow the recovery message on the form. If recovery is unavailable, keep the form open until you save or finish it.',
        ),
      ]) ...[SectionTitle(topic.$1), Surface(child: Text(topic.$2))],
    ],
  );
}
