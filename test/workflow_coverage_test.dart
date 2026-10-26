import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/app/feature_panels.dart';

void main() {
  test(
    'all 40 handover workflows have a mobile entry and declared ownership',
    () {
      final manifest = (jsonDecode(
        File('docs/validation/workflow-routes.json').readAsStringSync(),
      ) as List).cast<Map<String, dynamic>>();
      final expectedIds = {
        for (var index = 1; index <= 40; index++)
          "BF-${index.toString().padLeft(3, '0')}",
      };
      expect(manifest, hasLength(40));
      expect(manifest.map((r) => r['id']).toSet(), expectedIds);
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
