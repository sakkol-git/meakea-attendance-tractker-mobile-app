part of '../../../core/demo/local_service.dart';

extension IdentityScheduleSeed on LocalDataSource {
  void _seedSchedules() {
    _rows['/shifts'] = [
      {
        'id': 'shift-standard',
        'name': 'Standard workday',
        'startTime': '08:30',
        'endTime': '17:30',
        'siteId': 'site-headquarters',
        'timezone': 'Asia/Phnom_Penh',
        'days': 'Monday–Friday',
        'version': 1,
      },
    ];
    _rows['/work-sites'] = [
      {
        'id': 'site-headquarters',
        'name': 'Headquarters',
        'latitude': 11.5564,
        'longitude': 104.9282,
        'radiusM': 200,
        'timezone': 'Asia/Phnom_Penh',
        'status': 'ACTIVE',
        'version': 1,
      },
    ];
  }
}
