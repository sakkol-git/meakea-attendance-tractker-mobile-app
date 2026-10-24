import '../../../shared/presentation/case_page.dart';
import '../../../shared/presentation/case_fields.dart';

const attendancePanels = [
  CasePanel(
    'attendance.days',
    'Daily attendance',
    'Review each workday, its calculation and whether the result is provisional or finalized.',
    access: 'employee',
    dates: true,
    details: {
      'workDate': 'Work date',
      'dayStatus': 'Attendance result',
      'workedMinutes': 'Recorded minutes',
      'lateMinutes': 'Late minutes',
      'earlyMinutes': 'Early departure minutes',
      'source': 'Attendance source',
      'finalized': 'Finalized',
    },
  ),
  CasePanel(
    'attendance.team-days',
    'Team daily attendance',
    'Authorized daily results for your team. Revisions preserve the evidence used for each result.',
    access: 'manager',
    dates: true,
    details: {
      'employeeName': 'Employee',
      'workDate': 'Work date',
      'dayStatus': 'Attendance result',
      'workedMinutes': 'Recorded minutes',
      'lateMinutes': 'Late minutes',
      'finalized': 'Finalized',
    },
  ),
  CasePanel(
    'attendance.manual-history',
    'Manual attendance',
    'Independent HR entries remain distinguishable from employee taps and inferred records.',
    details: {
      'employeeName': 'Employee',
      'workDate': 'Work date',
      'checkInAt': 'Clock in',
      'checkOutAt': 'Clock out',
      'reason': 'Reason',
    },
    create: CaseAction(
      'attendance.manual',
      'Add manual attendance',
      fields: [
        employee,
        workDate,
        CaseField('checkIn', 'Clock in', kind: FieldKind.time),
        CaseField('checkOut', 'Clock out', kind: FieldKind.time),
        reason,
      ],
    ),
  ),
  CasePanel(
    'attendance.evidence',
    'Attendance evidence',
    'Review observations you have submitted and their processing result. Evidence does not itself confirm attendance.',
    access: 'employee',
    dates: true,
    details: {
      'workDate': 'Work date',
      'accuracyMeters': 'Location accuracy (m)',
      'capturedAt': 'Captured',
      'decision': 'Review outcome',
      'message': 'Outcome details',
    },
  ),
  CasePanel(
    'attendance.review',
    'Attendance finalization',
    'Review provisional employee days. Unresolved leave conflicts block finalization.',
    details: {
      'employeeName': 'Employee',
      'workDate': 'Work date',
      'dayStatus': 'Attendance result',
      'workedMinutes': 'Recorded minutes',
      'finalized': 'Finalized',
    },
    actions: [
      CaseAction(
        'attendance.finalize',
        'Finalize reviewed day',
        fields: [reason],
        when: independent,
      ),
    ],
  ),
];
