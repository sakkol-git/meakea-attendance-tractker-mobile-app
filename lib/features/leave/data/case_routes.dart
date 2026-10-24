import 'package:hrflow_mobile/core/data/case_repository.dart';

const leaveCaseRoutes = <String, CaseRoute>{
  'leave.balances': CaseRoute(
    '/leave/admin/balances',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'leave.ledger': CaseRoute(
    '/leave/admin/ledger',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'leave.adjust': CaseRoute(
    '/leave/admin/balances/{id}/adjust',
    method: 'POST',
    versioned: true,
    single: false,
  ),
  'leave.rollovers': CaseRoute(
    '/leave/admin/year-end',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'leave.rollover.preview': CaseRoute(
    '/leave/admin/year-end/preview',
    method: 'POST',
    versioned: false,
    single: false,
  ),
  'leave.rollover.apply': CaseRoute(
    '/leave/admin/year-end',
    method: 'POST',
    versioned: false,
    single: false,
  ),
  'leave.conflicts': CaseRoute(
    '/leave/conflicts',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'leave.conflict.resolve': CaseRoute(
    '/leave/requests/{id}/resolve-conflict',
    method: 'POST',
    versioned: true,
    single: false,
  ),
  'leave.calendar': CaseRoute(
    '/leave/calendar',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'leave.policies': CaseRoute(
    '/leave/admin/types',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'leave.policy.edit': CaseRoute(
    '/leave/admin/policies/{id}',
    method: 'PUT',
    versioned: true,
    single: false,
  ),
};
