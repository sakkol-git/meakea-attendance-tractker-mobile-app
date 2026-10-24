import 'package:hrflow_mobile/core/data/api_client.dart';
import 'package:hrflow_mobile/core/data/json.dart';
import 'package:hrflow_mobile/core/protocol.dart';

import '../domain/delegation.dart';

class DelegationRepository {
  final ApiClient client;
  const DelegationRepository(this.client);

  Future<List<ApprovalDelegation>> list() async {
    final response = await client.request(
      const DataRequest('GET', '/approvals/delegations'),
    );
    return items(response.data).map(ApprovalDelegation.fromJson).toList();
  }

  Future<List<EligibleDelegate>> candidates({
    String search = '',
    int page = 0,
  }) async {
    final response = await client.request(
      DataRequest(
        'GET',
        '/approvals/eligible-delegates',
        query: {'search': search, 'page': '$page', 'size': '25'},
      ),
    );
    return items(response.data).map(EligibleDelegate.fromJson).toList();
  }

  Future<ApprovalDelegation> create(
    String delegateId,
    String startsOn,
    String endsOn,
    String reason,
    String key,
  ) async {
    final response = await client.request(
      DataRequest(
        'POST',
        '/approvals/delegations',
        idempotencyKey: key,
        body: {
          'delegateId': delegateId,
          'startsOn': startsOn,
          'endsOn': endsOn,
          'reason': reason,
        },
      ),
    );
    return ApprovalDelegation.fromJson(object(response.data));
  }

  Future<void> cancel(ApprovalDelegation delegation) async {
    await client.request(
      DataRequest(
        'DELETE',
        '/approvals/delegations/${delegation.id}',
        ifMatch: delegation.etag,
      ),
    );
  }
}
