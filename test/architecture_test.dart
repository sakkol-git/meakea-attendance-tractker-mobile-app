import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new large source files and growth require a cohesion review', () {
    const reviewedLimits = <String, int>{
      'lib/app.dart': 336,
      'lib/core/data/cache/cached_source.dart': 324,
      'lib/core/demo/local_service.dart': 764,
      'lib/core/widgets.dart': 434,
      'lib/features/attendance/data/case_local.dart': 379,
      'lib/features/dashboard/presentation/home_page.dart': 402,
      'lib/features/identity/data/case_local.dart': 519,
      'lib/features/identity/data/session_client.dart': 384,
      'lib/features/identity/presentation/assignments_page.dart': 333,
      'lib/features/identity/presentation/case_pages.dart': 358,
      'lib/features/identity/presentation/people_pages.dart': 476,
      'lib/features/leave/data/case_local.dart': 515,
      'lib/features/requests/data/case_local.dart': 386,
      'lib/features/settings/presentation/settings_pages.dart': 308,
      'lib/features/workflows/data/local_handler.dart': 345,
      'lib/features/workflows/presentation/form_page.dart': 1019,
      'lib/features/workflows/presentation/workflow_lists.dart': 449,
      'lib/features/workflows/presentation/workflow_pages.dart': 489,
      'lib/shared/presentation/case_page.dart': 950,
    };
    final largeFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => MapEntry(file.path, file.readAsLinesSync().length))
        .where((entry) => entry.value > 300)
        .toList();
    for (final entry in largeFiles) {
      expect(
        reviewedLimits.containsKey(entry.key),
        true,
        reason: '${entry.key} has ${entry.value} lines and needs review',
      );
      expect(
        entry.value,
        lessThanOrEqualTo(reviewedLimits[entry.key]!),
        reason: '${entry.key} grew beyond its reviewed limit',
      );
    }
    for (final path in reviewedLimits.keys) {
      expect(File(path).existsSync(), true, reason: 'Stale exception: $path');
    }
  });

  test(
    'each business feature owns its domain, application and data adapters',
    () {
      for (final feature in [
        'identity',
        'attendance',
        'leave',
        'requests',
        'notifications',
        'reporting',
        'operations',
      ]) {
        for (final layer in ['domain', 'application', 'data', 'presentation']) {
          final files = Directory('lib/features/$feature/$layer')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))
              .toList();
          expect(files, isNotEmpty, reason: '$feature/$layer');
          for (final file in files) {
            final text = file.readAsStringSync();
            final imports = RegExp(r"(?:import|export)\s+'([^']+)'")
                .allMatches(text)
                .map((m) => m[1]!);
            if (layer == 'domain') {
              expect(
                imports.any(
                  (i) =>
                      i.contains('/data/') ||
                      i.contains('flutter') ||
                      i.contains('/presentation/'),
                ),
                false,
                reason: file.path,
              );
            }
            if (layer == 'application' || layer == 'presentation') {
              expect(
                imports.any((i) => i.contains('/data/')),
                false,
                reason: file.path,
              );
            }
          }
        }
      }
    },
  );
  test('no all-feature repository ships in the application', () {
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      expect(
        file.readAsStringSync(),
        isNot(contains('class HrRepository')),
        reason: file.path,
      );
      expect(
        file.readAsStringSync(),
        isNot(contains('interface class WorkspaceRepository')),
        reason: file.path,
      );
    }
  });
}
