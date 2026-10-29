import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hrflow_mobile/core/data/remote_source.dart';
import 'package:hrflow_mobile/core/protocol.dart';

void main() {
  test(
    'private CSV uses authenticated API transport, UTF-8 and no cache',
    () async {
      final source = RemoteDataSource(
        'https://hr.test/api/v1',
        () => 'current-access',
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://hr.test/api/v1/reports/exports/123/download',
          );
          expect(request.headers['Authorization'], 'Bearer current-access');
          expect(request.followRedirects, isFalse);
          return http.Response.bytes(
            utf8.encode('name\nសួស្តី\n'),
            200,
            headers: {'content-type': 'text/csv', 'cache-control': 'no-store'},
          );
        }),
      );
      final response = await source.send(
        const DataRequest(
          'GET',
          '/reports/exports/123/download',
          responseType: 'csv',
        ),
      );
      expect(response.data, 'name\nសួស្តី\n');
      expect(response.cacheAllowed, isFalse);
      source.close();
    },
  );
}
