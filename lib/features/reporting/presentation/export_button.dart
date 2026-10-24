import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/widgets.dart';
import '../application/providers.dart';

class ExportDownloadButton extends ConsumerWidget {
  final String id;
  const ExportDownloadButton(this.id, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => BusyButton(
    label: 'Download or share CSV',
    action: () async {
      final file = await ref
          .read(reportingRepositoryProvider)
          .downloadExport(id);
      if (!context.mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(file.bytes, mimeType: 'text/csv', name: file.name),
          ],
          fileNameOverrides: [file.name],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    },
  );
}
