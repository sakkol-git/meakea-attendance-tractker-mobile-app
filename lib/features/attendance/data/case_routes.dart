import 'package:hrflow_mobile/core/data/case_repository.dart';

const attendanceCaseRoutes = <String, CaseRoute>{
  'attendance.sites': CaseRoute('/attendance/work-sites/me'),
  'attendance.days': CaseRoute(
    '/attendance/daily-status/me',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'attendance.team-days': CaseRoute(
    '/attendance/daily-status',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'attendance.evidence': CaseRoute(
    '/attendance/evidence/me',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'attendance.capture': CaseRoute(
    '/attendance/evidence',
    method: 'POST',
    versioned: false,
    single: false,
  ),
  'attendance.manual': CaseRoute(
    '/attendance/manual',
    method: 'POST',
    versioned: false,
    single: false,
  ),
  'attendance.manual-history': CaseRoute(
    '/attendance/manual',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'attendance.review': CaseRoute(
    '/attendance/reviews',
    method: 'GET',
    versioned: false,
    single: false,
  ),
  'attendance.finalize': CaseRoute(
    '/attendance/daily-status/{id}/finalize',
    method: 'POST',
    versioned: true,
    single: false,
  ),
};
