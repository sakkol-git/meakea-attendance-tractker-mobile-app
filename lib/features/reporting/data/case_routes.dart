import 'package:hrflow_mobile/core/data/case_repository.dart';

const reportingCaseRoutes = <String, CaseRoute>{
  'reporting.attendance': CaseRoute(
    '/reports/attendance/summary',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'reporting.late': CaseRoute(
    '/reports/attendance/late-ranking',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'reporting.leave': CaseRoute(
    '/reports/leave/summary',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'reporting.balances': CaseRoute(
    '/reports/leave/balances',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'reporting.requests': CaseRoute(
    '/reports/requests/summary',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'reporting.exports': CaseRoute(
    '/reports/exports',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'reporting.export.create': CaseRoute(
    '/reports/exports',
    method: 'POST',
    versioned: false,
    single: false,
  ),
  'reporting.rebuilds': CaseRoute(
    '/reports/admin/rebuilds',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'reporting.rebuild.start': CaseRoute(
    '/reports/admin/rebuilds',
    method: 'POST',
    versioned: false,
    single: false,
  ),
};
