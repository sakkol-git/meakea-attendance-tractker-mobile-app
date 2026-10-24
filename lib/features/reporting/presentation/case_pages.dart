import '../../../shared/presentation/case_page.dart';
import '../../../shared/presentation/case_fields.dart';

const reportingPanels = [
  CasePanel(
    'reporting.attendance',
    'Attendance report',
    'Recorded work and attendance results by employee. Reports may lag owner records.',
    access: 'manager',
    dates: true,
    details: {
      'employeeName': 'Employee',
      'sessions': 'Sessions',
      'workedMinutes': 'Recorded minutes',
      'lateDays': 'Late days',
      'absentDays': 'Absent days',
      'asOf': 'Updated',
    },
  ),
  CasePanel(
    'reporting.late',
    'Late-arrival review',
    'Review late-day totals alongside attendance records, not as an automated employment decision.',
    access: 'manager',
    dates: true,
    details: {
      'employeeName': 'Employee',
      'lateDays': 'Late days',
      'lateMinutes': 'Late minutes',
      'asOf': 'Updated',
    },
  ),
  CasePanel(
    'reporting.leave',
    'Leave report',
    'Approved and pending leave totals for your authorized people.',
    access: 'manager',
    dates: true,
    details: {
      'employeeName': 'Employee',
      'approvedDays': 'Approved days',
      'pendingDays': 'Pending days',
      'asOf': 'Updated',
    },
  ),
  CasePanel(
    'reporting.balances',
    'Leave balance report',
    'A report projection of balances. Use Leave accounting for authoritative adjustments.',
    details: {
      'employeeName': 'Employee',
      'typeName': 'Leave type',
      'available': 'Available days',
      'pending': 'Reserved days',
      'used': 'Used days',
      'asOf': 'Updated',
    },
  ),
  CasePanel(
    'reporting.requests',
    'Request report',
    'Request counts and completion by employee.',
    access: 'manager',
    dates: true,
    details: {
      'employeeName': 'Employee',
      'pending': 'Pending',
      'approved': 'Approved',
      'fulfilled': 'Fulfilled',
      'asOf': 'Updated',
    },
  ),
  CasePanel(
    'reporting.exports',
    'Export history',
    'Review report jobs and failures before downloading or sharing employee information.',
    access: 'manager',
    details: {
      'report': 'Report',
      'format': 'Format',
      'createdAt': 'Created',
      'fileName': 'File',
    },
    create: CaseAction(
      'reporting.export.create',
      'Prepare report export',
      fields: [
        CaseField(
          'report',
          'Report',
          kind: FieldKind.choice,
          choices: {
            'ATTENDANCE': 'Attendance',
            'LEAVE': 'Leave',
            'REQUESTS': 'Requests',
          },
          initial: 'ATTENDANCE',
        ),
        CaseField('from', 'From', kind: FieldKind.date),
        CaseField('to', 'Until', kind: FieldKind.date),
        CaseField(
          'format',
          'Format',
          kind: FieldKind.choice,
          choices: {'CSV': 'CSV spreadsheet'},
          initial: 'CSV',
        ),
      ],
    ),
  ),
  CasePanel(
    'reporting.rebuilds',
    'Report recovery',
    'Review or request an authorized projection rebuild. Source records remain authoritative.',
    access: 'owner',
    details: {
      'reason': 'Reason',
      'createdAt': 'Requested',
      'completedAt': 'Completed',
      'message': 'Recovery result',
    },
    create: CaseAction(
      'reporting.rebuild.start',
      'Request report rebuild',
      fields: [reason],
      when: ownerOnly,
    ),
  ),
];
