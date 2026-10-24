import 'package:hrflow_mobile/features/identity/domain/models.dart';

import '../../../shared/domain/cases.dart';
import '../../../shared/presentation/case_page.dart';
import '../../../shared/presentation/case_fields.dart';

const leavePanels = [
  CasePanel(
    'leave.balances',
    'Leave accounting',
    'Review employee balances before making a reasoned ledger adjustment.',
    details: {
      'employeeName': 'Employee',
      'typeName': 'Leave type',
      'year': 'Year',
      'entitled': 'Entitled days',
      'carriedOver': 'Carried days',
      'used': 'Used days',
      'pending': 'Reserved days',
      'available': 'Available days',
    },
    actions: [
      CaseAction(
        'leave.adjust',
        'Adjust entitlement',
        targetField: 'employeeId',
        inherit: ['leaveTypeId', 'year'],
        fields: [
          CaseField(
            'delta',
            'Adjustment in days (positive or negative)',
            kind: FieldKind.number,
            minimum: -366,
            maximum: 366,
          ),
          reason,
        ],
        when: independent,
      ),
    ],
  ),
  CasePanel(
    'leave.ledger',
    'Leave ledger',
    'Reservation, use, release, adjustment and carry-over entries remain visible.',
    dates: true,
    details: {
      'employeeName': 'Employee',
      'typeName': 'Leave type',
      'kind': 'Entry',
      'days': 'Days',
      'reason': 'Reason',
      'createdAt': 'Recorded',
    },
  ),
  CasePanel(
    'leave.rollovers',
    'Year-end carry-over',
    'Preview eligible balances and an explicit carry-over limit before applying a closing-year job.',
    details: {
      'fromYear': 'Closing year',
      'toYear': 'Next year',
      'carryLimit': 'Maximum carry-over days',
      'appliedEmployees': 'Employees updated',
      'createdAt': 'Created',
    },
    create: CaseAction(
      'leave.rollover.apply',
      'Prepare year-end rollover',
      prepare: 'leave.rollover.preview',
      fields: [
        CaseField(
          'fromYear',
          'Closing year',
          kind: FieldKind.integer,
          initial: '@year',
          minimum: 2020,
          maximum: 2099,
        ),
        CaseField(
          'carryLimit',
          'Approved maximum carry-over days',
          kind: FieldKind.number,
          minimum: 0,
          maximum: 366,
        ),
        reason,
      ],
    ),
  ),
  CasePanel(
    'leave.conflicts',
    'Leave conflict review',
    'Keep attendance evidence intact. An independent reviewer explicitly keeps or cancels affected leave.',
    details: {
      'employeeName': 'Employee',
      'workDate': 'Work date',
      'typeName': 'Leave type',
      'reason': 'Conflict',
      'attendanceSummary': 'Recorded work',
      'resolution': 'Resolution',
    },
    actions: [
      CaseAction(
        'leave.conflict.resolve',
        'Resolve conflict',
        targetField: 'leaveRequestId',
        inherit: ['conflictId'],
        fields: [
          CaseField(
            'action',
            'Resolution',
            kind: FieldKind.choice,
            choices: {
              'KEEP_LEAVE': 'Keep approved leave',
              'CANCEL_LEAVE': 'Cancel leave and compensate balance',
            },
          ),
          reason,
        ],
        when: conflictAwaitingReview,
      ),
    ],
  ),
  CasePanel(
    'leave.calendar',
    'Team leave calendar',
    'Approved leave and pending reservations for the people you are allowed to view.',
    access: 'manager',
    dates: true,
    details: {
      'employeeName': 'Employee',
      'startDate': 'From',
      'endDate': 'Until',
      'days': 'Days',
      'typeName': 'Leave type',
    },
  ),
  CasePanel(
    'leave.policies',
    'Leave policies',
    'Set entitlement, carry-over and request requirements for each leave type.',
    details: {
      'entitled': 'Annual days',
      'carryOverMax': 'Carry-over maximum',
      'allowHalfDay': 'Half-day leave',
      'requiresAttachment': 'Evidence required',
      'maxDaysPerRequest': 'Maximum request days',
    },
    actions: [
      CaseAction(
        'leave.policy.edit',
        'Edit leave policy',
        fields: [
          CaseField(
            'annualDays',
            'Annual entitlement in days',
            kind: FieldKind.number,
            minimum: 0,
            maximum: 366,
          ),
          CaseField(
            'carryOverMax',
            'Maximum carry-over days',
            kind: FieldKind.number,
            minimum: 0,
            maximum: 366,
          ),
          CaseField(
            'maxDaysPerRequest',
            'Maximum days per request',
            kind: FieldKind.integer,
            minimum: 1,
            maximum: 366,
            initial: 60,
          ),
          CaseField(
            'allowHalfDay',
            'Allow half-day requests',
            kind: FieldKind.toggle,
            initial: true,
          ),
          CaseField(
            'requiresAttachment',
            'Require supporting evidence',
            kind: FieldKind.toggle,
          ),
          reason,
        ],
      ),
    ],
  ),
];

bool conflictAwaitingReview(CaseRecord? row, Profile actor) =>
    independent(row, actor) && row?.status == 'NEEDS_REVIEW';
