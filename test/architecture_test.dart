import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
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
