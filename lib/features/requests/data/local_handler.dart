part of '../../../core/demo/local_service.dart';

extension RequestsDemo on LocalDataSource {
  void _validateRequests(String path, JsonMap body) {
    _need(
      (body['title'] as String? ?? '').trim().length >= 3,
      'VALIDATION_ERROR',
      'Enter a request title.',
    );
    body['type'] ??= 'GENERAL';
    _need(
      _requestTypes.any(
        (t) => t['code'] == body['type'] && t['active'] == true,
      ),
      'REQUEST_POLICY',
      'Choose an available request category.',
    );
    if (body['type'] == 'MATERIAL') {
      final items = body['items'] as List? ?? [];
      _need(items.isNotEmpty, 'VALIDATION_ERROR', 'Add at least one material.');
      final seen = <String>{};
      for (final item in items) {
        final id = item['materialId'] as String? ?? '',
            quantity = item['quantity'];
        _need(
          _table('/materials')
                  .any((m) => m['id'] == id && m['status'] != 'ARCHIVED') &&
              seen.add(id),
          'VALIDATION_ERROR',
          'Choose each material once.',
        );
        _need(
          quantity is num &&
              quantity.isFinite &&
              quantity % 1 == 0 &&
              quantity > 0 &&
              quantity <= 100000,
          'VALIDATION_ERROR',
          'Enter a positive whole quantity.',
        );
      }
    }
    if (body['startDate'] != null || body['endDate'] != null) {
      _need(
        _validDate(body['startDate']) &&
            _validDate(body['endDate']) &&
            (body['endDate'] as String).compareTo(body['startDate']) >= 0,
        'VALIDATION_ERROR',
        'Choose a valid request date range.',
      );
    }
  }

  DataResponse? _handleRequests(DataRequest r) {
    final caseResult = _requestsCases(r);
    if (caseResult != null) return caseResult;
    return _catalogue(r, ['/materials']);
  }
}
