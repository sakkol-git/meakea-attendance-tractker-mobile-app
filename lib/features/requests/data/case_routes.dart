import 'package:hrflow_mobile/core/data/case_repository.dart';

const requestsCaseRoutes = <String, CaseRoute>{
  'requests.types': CaseRoute(
    '/requests/admin/types',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'requests.type.create': CaseRoute(
    '/requests/admin/types',
    method: 'POST',
    versioned: false,
    single: false,
  ),
  'requests.type.edit': CaseRoute(
    '/requests/admin/types/{id}',
    method: 'PATCH',
    versioned: true,
    single: false,
  ),
  'requests.inventory': CaseRoute(
    '/materials/admin',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'requests.stock.receive': CaseRoute(
    '/materials/admin/{id}/receive',
    method: 'POST',
    versioned: true,
    single: false,
  ),
  'requests.issues': CaseRoute(
    '/materials/issues',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'requests.chains': CaseRoute(
    '/requests/admin/approval-chains',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'requests.chain.create': CaseRoute(
    '/requests/admin/approval-chains',
    method: 'POST',
    versioned: false,
    single: false,
  ),
  'requests.chain.edit': CaseRoute(
    '/requests/admin/approval-chains/{id}',
    method: 'PATCH',
    versioned: true,
    single: false,
  ),
  'requests.fulfillment': CaseRoute(
    '/requests/approved-materials',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'requests.issue': CaseRoute(
    '/requests/{id}/fulfill',
    method: 'POST',
    versioned: true,
    single: false,
  ),
  'requests.comment': CaseRoute(
    '/requests/{id}/comments',
    method: 'POST',
    versioned: true,
    single: false,
  ),
};
