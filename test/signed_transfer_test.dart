import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hrflow_mobile/features/attachments/data/signed_transfer.dart';
import 'package:hrflow_mobile/core/protocol.dart';

void main() {
  test(
    'legacy signed transfer refuses redirects and API credential headers',
    () async {
      final client = MockClient((r) async {
        expect(r.followRedirects, isFalse);
        expect(r.headers.containsKey('Authorization'), isFalse);
        return http.Response(
          '',
          302,
          headers: {'location': 'https://foreign.test/file'},
        );
      });
      addTearDown(client.close);
      await expectLater(
        signedTransfer(
          'GET',
          Uri.parse('https://files.test/file'),
          client: client,
        ),
        throwsA(isA<DataFailure>()),
      );
    },
  );
}
