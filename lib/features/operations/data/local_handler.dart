part of '../../../core/demo/local_service.dart';

extension OperationsDemo on LocalDataSource {
  DataResponse? _operationsCases(DataRequest r) {
    if (r.path != '/operations/workflow-status' || r.method != 'GET') {
      return null;
    }
    _need(
      _actor == 'OWNER',
      'FORBIDDEN',
      'Owner access is required.',
      status: 403,
    );
    const entries = [
      (
        '032',
        'Confidence scoring',
        'Confidence service',
        'Standalone scoring exists in the source prototype. The demo does not invoke it or create inferred attendance automatically.',
      ),
      (
        '033',
        'Model health & metadata',
        'Confidence service',
        'Production model readiness must be supplied by a protected health endpoint. No service connection is configured in this demo.',
      ),
      (
        '034',
        'Model training',
        'ML operator',
        'Training, synthetic data and model promotion run outside the mobile app in the secured operations environment.',
      ),
      (
        '035',
        'Owner event publication',
        'Owner services',
        'Outbox publication and relay recovery are backend duties. Local mutations do not publish Kafka events.',
      ),
      (
        '036',
        'Consumer retry & dead letter',
        'Consumer services',
        'Retry, replay and dead-letter recovery require backend operator tools and trusted tenant scope.',
      ),
      (
        '037',
        'Attendance shift cutoff',
        'Attendance service',
        'Cutoff scheduling and finalization jobs run on the server. HR can explicitly review a day from Attendance finalization.',
      ),
      (
        '038',
        'Reference bootstrap',
        'Owner services',
        'Reference bootstrap and lag readiness are server responsibilities. Local data is initialized from fictional fixtures.',
      ),
      (
        '039',
        'Technical readiness & API documentation',
        'Gateway / service owners',
        'The repository has service scaffolding; agreed business APIs and replay-aware readiness endpoints must be implemented and verified before production integration.',
      ),
    ];
    return _page([
      for (final e in entries)
        {
          'id': 'bf-${e.$1}',
          'title': e.$2,
          'workflow': 'BF-${e.$1}',
          'owner': e.$3,
          'message': e.$4,
          'status': 'NOT_CONNECTED',
          'observedAt': _now().toIso8601String(),
          'version': 1,
        },
    ], r);
  }
}
