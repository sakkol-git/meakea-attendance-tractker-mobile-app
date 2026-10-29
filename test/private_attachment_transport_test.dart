import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hrflow_mobile/core/data/remote_source.dart';
import 'package:hrflow_mobile/core/protocol.dart';

void main() {
  test('private bytes retain auth, exact paths and no redirects; file response bypasses cache', () async {
    final source = RemoteDataSource(
      'https://hr.test/prefix/api/v1',
      () => 'access',
      client: MockClient((r) async {
        expect(r.headers['Authorization'], 'Bearer access');
        expect(r.followRedirects, isFalse);
        expect(
          r.url.path,
          startsWith('/prefix/api/v1/requests/request-a/attachments/file-a/'),
        );
        if (r.method == 'PUT') {
          expect(r.bodyBytes, [1, 2, 255]);
          expect(r.headers['Content-Type'], 'application/pdf');
          return http.Response('', 200);
        }
        return http.Response.bytes(
          [1, 2, 255],
          200,
          headers: {'content-type': 'application/pdf'},
        );
      }),
    );
    addTearDown(source.close);
    await source.send(
      DataRequest(
        'PUT',
        '/requests/request-a/attachments/file-a/upload',
        bytes: Uint8List.fromList([1, 2, 255]),
        contentType: 'application/pdf',
      ),
    );
    final result = await source.send(
      const DataRequest(
        'GET',
        '/requests/request-a/attachments/file-a/file',
        responseType: 'bytes',
      ),
    );
    expect(result.data, [1, 2, 255]);
    expect(result.cacheAllowed, isFalse);
  });
  test(
    'binary responses outside private attachment paths fail before networking',
    () async {
      var sent = false;
      final source = RemoteDataSource(
        'https://hr.test/api/v1',
        () => 'access',
        client: MockClient((r) async {
          sent = true;
          return http.Response('', 200);
        }),
      );
      addTearDown(source.close);
      await expectLater(
        source.send(
          const DataRequest('GET', '/auth/me', responseType: 'bytes'),
        ),
        throwsA(isA<DataFailure>()),
      );
      expect(sent, isFalse);
    },
  );
}
