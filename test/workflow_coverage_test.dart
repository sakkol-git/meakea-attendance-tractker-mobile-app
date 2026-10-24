import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/app/feature_panels.dart';

void main() {
  test(
    'all 40 source workflows have a mobile entry and declared ownership',
    () {
      final manifest = (jsonDecode(
        File('docs/validation/workflow-routes.json').readAsStringSync(),
      ) as List).cast<Map<String, dynamic>>();
      final source = File('../business-flow.md').readAsStringSync();
      final ids = RegExp(r'\| (BF-\d{3}) \|')
          .allMatches(source)
          .map((m) => m[1])
          .toSet();
      expect(ids, hasLength(40));
      expect(manifest.map((r) => r['id']).toSet(), ids);
      for (final item in manifest) {
        expect(item['boundary'], isNotEmpty);
        expect(item['module'], isNotEmpty);
        final route = item['route'] as String;
        if (route.startsWith('/features/')) {
          expect(
            panelFor(route.split('/').last),
            isNotNull,
            reason: item['id'],
          );
        }
      }
    },
  );
}
