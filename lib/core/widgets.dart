import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/design_tokens.dart';
import 'package:hrflow_mobile/core/presentation_format.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/core/theme.dart';

export 'package:hrflow_mobile/core/presentation_format.dart';

class AppPage extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? bottom;
  final Future<void> Function()? onRefresh;
  final Future<bool> Function()? canLeave;
  const AppPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.actions,
    this.bottom,
    this.onRefresh,
    this.canLeave,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final content = ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: pageInsets(
        context,
        bottom: keyboardVisible ? AppSpacing.x6 : AppSpacing.x8,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (ref.watch(staleResourcesProvider).asData?.value
            case final resources? when resources.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x4),
            child: Semantics(
              liveRegion: true,
              child: Surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Showing saved data',
                      style: TextStyle(
                        color: context.semantic.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    for (final resource in resources)
                      Text(
                        '${resource.path.split('?').first}: Last updated ${companyTimestamp(resource.savedAt.toIso8601String())}',
                      ),
                    const SizedBox(height: AppSpacing.x2),
                    const Text(
                      'Changes to these resources require a connection so the latest version and permissions can be checked.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x6),
            child: Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.semantic.textMuted),
            ),
          ),
        ...children,
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        leading:
            !Navigator.of(context).canPop() &&
                ![
                  '/home',
                  '/activity',
                  '/requests',
                  '/leave',
                  '/profile',
                  '/approvals',
                  '/workflows',
                ].contains(
                  GoRouter.of(context).routeInformationProvider.value.uri.path,
                )
            ? IconButton(
                tooltip: 'Back to workspace',
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  if (canLeave != null && !await canLeave!()) return;
                  if (context.mounted) context.go('/home');
                },
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSize.contentMax),
            child: onRefresh == null
                ? content
                : RefreshIndicator(
                    onRefresh: () async {
                      await ref.read(clientProvider).clearCache();
                      await onRefresh!();
                    },
                    child: content,
                  ),
          ),
        ),
      ),
      bottomNavigationBar: bottom,
    );
  }
}

class Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.x4),
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: padding, child: child),
  );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? action;
  const SectionTitle(this.text, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.x6, bottom: AppSpacing.x3),
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?action,
      ],
    ),
  );
}

class AsyncPanel<T> extends ConsumerWidget {
  final AsyncValue<T> value;
  final Widget Function(T) builder;
  final VoidCallback retry;
  const AsyncPanel({
    super.key,
    required this.value,
    required this.builder,
    required this.retry,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) => value.when(
    data: builder,
    loading: () => const Padding(
      padding: EdgeInsets.all(AppSpacing.x8),
      child: Center(
        child: CircularProgressIndicator(semanticsLabel: 'Loading'),
      ),
    ),
    error: (e, _) => Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_outlined, color: context.semantic.textMuted),
          const SizedBox(height: AppSpacing.x3),
          Text(message(e)),
          const SizedBox(height: AppSpacing.x3),
          Wrap(
            spacing: AppSpacing.x2,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(clientProvider).clearCache();
                  retry();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
              if (e is DataFailure && e.status == 401)
                TextButton(
                  onPressed: () => ref.read(sessionProvider.notifier).signOut(),
                  child: const Text('Sign in again'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title, description;
  final IconData icon;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.inbox_outlined,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Surface(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
      child: Column(
        children: [
          Icon(icon, size: 36, color: context.semantic.textMuted),
          const SizedBox(height: AppSpacing.x3),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(description, textAlign: TextAlign.center),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.x4),
              child: action,
            ),
        ],
      ),
    ),
  );
}

class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final success = [
          'APPROVED',
          'CONFIRMED',
          'FULFILLED',
          'COMPLETED',
          'ACTIVE',
        ].contains(status),
        danger = ['REJECTED', 'FAILED', 'INACTIVE'].contains(status),
        pending = ['PENDING', 'QUEUED', 'REVIEW_NEEDED'].contains(status);
    final semantic = context.semantic;
    final color = success
        ? semantic.success
        : danger
        ? semantic.error
        : pending
        ? semantic.warning
        : semantic.textMuted;
    final background = success
        ? semantic.successBackground
        : danger
        ? semantic.errorBackground
        : pending
        ? semantic.warningBackground
        : semantic.card;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x3,
        vertical: AppSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label, value;
  const InfoRow(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: context.semantic.textMuted),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

class BusyButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Future<void> Function() action;
  final bool enabled;
  const BusyButton({
    super.key,
    required this.label,
    required this.action,
    this.icon,
    this.enabled = true,
  });
  @override
  State<BusyButton> createState() => _BusyButtonState();
}

class _BusyButtonState extends State<BusyButton> {
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(error!, style: TextStyle(color: context.semantic.error)),
        ),
      FilledButton.icon(
        onPressed: busy || !widget.enabled
            ? null
            : () async {
                setState(() {
                  busy = true;
                  error = null;
                });
                try {
                  await widget.action();
                } catch (e) {
                  if (mounted) setState(() => error = message(e));
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
        icon: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(widget.icon ?? Icons.arrow_forward, size: 20),
        label: Text(busy ? 'Please wait…' : widget.label),
      ),
    ],
  );
}

void toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
