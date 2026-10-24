part of '../../../core/demo/local_service.dart';

extension ReviewContextDemo on LocalDataSource {
  JsonMap _reviewContext(String path, JsonMap row) {
    final context = <String, dynamic>{
      'steps': copyJson(row['decisions'] ?? []),
      'nextReviewer':
          row['currentApproverName'] ??
          (row['approvalStage'] == 'HR' ? 'HR reviewer' : 'Manager'),
    };
    if (path == '/leave/requests') {
      final startDate = '${row['startDate'] ?? ''}';
      final year = startDate.length >= 4
          ? int.tryParse(startDate.substring(0, 4)) ?? _companyNow.year
          : _companyNow.year;
      final balance = _leaveBalancesFor(
        row['employeeId'] as String,
        year,
      ).where((item) => item['leaveTypeId'] == row['leaveTypeId']).firstOrNull;
      final requester = _rows['/employees']!
          .where((person) => person['id'] == row['employeeId'])
          .firstOrNull;
      final department = requester?['departmentId'];
      final off = _rows['/leave/requests']!
          .where(
            (other) =>
                other['employeeId'] != row['employeeId'] &&
                other['status'] == 'APPROVED' &&
                '${other['startDate']}'.compareTo('${row['endDate']}') <= 0 &&
                '${other['endDate']}'.compareTo('${row['startDate']}') >= 0 &&
                _rows['/employees']!.any(
                  (person) =>
                      person['id'] == other['employeeId'] &&
                      person['departmentId'] == department,
                ),
          )
          .map((other) => other['employeeName'] ?? other['employeeId'])
          .toList();
      context.addAll({
        'chargeableDays': row['days'] ?? 0,
        'balanceAfter': balance?['available'],
        'teamMembersOff': off,
      });
    }
    if (path == '/requests' && row['type'] == 'MATERIAL') {
      context['materials'] = [
        for (final item in row['items'] as List? ?? [])
          if (item is Map)
            {
              'name':
                  _rows['/materials']!
                      .where((material) => material['id'] == item['materialId'])
                      .firstOrNull?['name'] ??
                  item['materialId'],
              'requested': item['quantity'],
              'stockAvailable':
                  _rows['/materials']!
                      .where((material) => material['id'] == item['materialId'])
                      .firstOrNull?['stock'] ??
                  10,
            },
      ];
    }
    return context;
  }
}
