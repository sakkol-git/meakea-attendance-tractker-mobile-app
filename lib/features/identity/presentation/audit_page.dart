import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/shared/domain/cases.dart';
import 'package:hrflow_mobile/shared/presentation/case_page.dart';

typedef AuditQuery = ({
  String actor,
  String action,
  String target,
  String from,
  String to,
  int page,
});

final auditRowsProvider = FutureProvider.autoDispose
    .family<List<CaseRecord>, AuditQuery>(
      (ref, query) => ref
          .watch(identityRepositoryProvider)
          .cases(
            'identity.audit',
            filters: {
              'page': '${query.page}',
              'size': '25',
              if (query.actor.isNotEmpty) 'actor': query.actor,
              if (query.action.isNotEmpty) 'action': query.action,
              if (query.target.isNotEmpty) 'target': query.target,
              if (query.from.isNotEmpty) 'from': query.from,
              if (query.to.isNotEmpty) 'to': query.to,
            },
          ),
    );

class AuditPage extends ConsumerStatefulWidget {
  const AuditPage({super.key});
  @override
  ConsumerState<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends ConsumerState<AuditPage> {
  String actor = '', action = '', target = '';
  DateTimeRange? range;
  int page = 0;
  Timer? debounce;

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  void filter(String field, String value) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        if (field == 'actor') actor = value.trim();
        if (field == 'action') action = value.trim();
        if (field == 'target') target = value.trim();
        page = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    String date(DateTime? d) => d?.toIso8601String().substring(0, 10) ?? '';
    final query = (
      actor: actor,
      action: action,
      target: target,
      from: date(range?.start),
      to: date(range?.end),
      page: page,
    );
    final provider = auditRowsProvider(query);
    final rows = ref.watch(provider);
    return AppPage(
      title: 'Audit activity',
      subtitle: 'A record of decisions and changes.',
      onRefresh: () async {
        ref.invalidate(provider);
        await ref.read(provider.future);
      },
      children: [
        TextField(
          decoration: const InputDecoration(labelText: 'Filter actor'),
          onChanged: (value) => filter('actor', value),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(labelText: 'Filter action'),
          onChanged: (value) => filter('action', value),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(labelText: 'Filter target'),
          onChanged: (value) => filter('target', value),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.date_range_outlined),
          label: Text(
            range == null
                ? 'Choose date range'
                : '${shortDate(date(range!.start))} – ${shortDate(date(range!.end))}',
          ),
          onPressed: () async {
            final now = ref.read(clockProvider)();
            final value = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(now.year + 2, 12, 31),
              initialDateRange: range,
            );
            if (value != null && mounted) {
              setState(() {
                range = value;
                page = 0;
              });
            }
          },
        ),
        if (range != null)
          TextButton(
            onPressed: () => setState(() {
              range = null;
              page = 0;
            }),
            child: const Text('Clear dates'),
          ),
        const SizedBox(height: 16),
        AsyncPanel(
          value: rows,
          retry: () => ref.invalidate(provider),
          builder: (items) => items.isEmpty
              ? const EmptyState(
                  title: 'No audit activity found',
                  description:
                      'Try another actor, action, target or date range.',
                  icon: Icons.history_outlined,
                )
              : Column(
                  children: [
                    for (final record in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AuditEntry(record: record),
                      ),
                  ],
                ),
        ),
        if (rows.asData != null)
          Row(
            children: [
              Text('Page ${page + 1}'),
              const Spacer(),
              TextButton(
                onPressed: page == 0 ? null : () => setState(() => page--),
                child: const Text('Previous'),
              ),
              TextButton(
                onPressed: rows.asData!.value.length < 25
                    ? null
                    : () => setState(() => page++),
                child: const Text('Next'),
              ),
            ],
          ),
      ],
    );
  }
}

class _AuditEntry extends StatelessWidget {
  final CaseRecord record;
  const _AuditEntry({required this.record});
  @override
  Widget build(BuildContext context) {
    String value(Object? input) =>
        input is String ? input : businessValue(input);
    final row = record.values;
    final changes = row['changes'] as Map? ?? {};
    return Surface(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(
          statusLabel(row['action']?.toString() ?? 'Activity'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${row['actor'] ?? row['actorId'] ?? 'Unknown actor'} · ${companyTimestamp(row['at']?.toString())}',
          style: TextStyle(color: context.semantic.textMuted),
        ),
        children: [
          InfoRow('Exact time', companyTimestamp(row['at']?.toString())),
          InfoRow(
            'Actor',
            (row['actor'] ?? row['actorId'] ?? 'Unknown').toString(),
          ),
          InfoRow(
            'Action',
            statusLabel(row['action']?.toString() ?? 'Activity'),
          ),
          InfoRow(
            'Target',
            (row['entityId'] ?? row['targetId'] ?? 'Unavailable').toString(),
          ),
          InfoRow('Reason', (row['reason'] ?? 'Not supplied').toString()),
          for (final entry in changes.entries)
            if (entry.value is Map)
              InfoRow(
                entry.key.toString(),
                '${value((entry.value as Map)['before'])} → ${value((entry.value as Map)['after'])}',
              ),
        ],
      ),
    );
  }
}
