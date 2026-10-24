import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/core/widgets.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:share_plus/share_plus.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});
  @override
  ConsumerState<ReportsPage> createState() => _ReportsState();
}

class _ReportsState extends ConsumerState<ReportsPage> {
  String? key;
  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Reports',
    subtitle: 'A clear view of your team’s activity.',
    onRefresh: () async {
      ref.invalidate(reportProvider);
      await ref.read(reportProvider.future);
    },
    children: [
      AsyncPanel(
        value: ref.watch(reportProvider),
        retry: () => ref.invalidate(reportProvider),
        builder: (r) => Column(
          children: [
            for (final e in [
              ('People', r['employees'], Icons.people_outline),
              (
                'Recorded sessions',
                r['attendanceSessions'],
                Icons.schedule_outlined,
              ),
              ('Pending leave', r['pendingLeave'], Icons.beach_access_outlined),
              (
                'Pending requests',
                r['pendingRequests'],
                Icons.assignment_outlined,
              ),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Surface(
                  child: Row(
                    children: [
                      Icon(e.$3, color: Palette.teal),
                      const SizedBox(width: 16),
                      Expanded(child: Text(e.$1)),
                      Text(
                        '${e.$2 ?? 0}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      const SectionTitle('Export attendance'),
      const Text(
        'Download a CSV of recorded sessions. Exported files can contain employee information; share them only with authorized people.',
        style: TextStyle(color: Palette.muted),
      ),
      const SizedBox(height: 16),
      BusyButton(
        label: 'Export & share CSV',
        icon: Icons.file_download_outlined,
        action: () async {
          key ??= commandKey();
          final file = await ref
              .read(reportingRepositoryProvider)
              .exportAttendance(key!);
          key = null;
          if (context.mounted) {
            final box = context.findRenderObject() as RenderBox?;
            await SharePlus.instance.share(
              ShareParams(
                files: [XFile.fromData(file.bytes, mimeType: 'text/csv')],
                fileNameOverrides: [file.name],
                sharePositionOrigin: box == null
                    ? null
                    : box.localToGlobal(Offset.zero) & box.size,
              ),
            );
          }
        },
      ),
    ],
  );
}
