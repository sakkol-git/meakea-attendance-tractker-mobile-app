import '../../../shared/presentation/case_page.dart';
import '../../../shared/presentation/case_fields.dart';

const identityPanels = [
  CasePanel(
    'identity.assignments',
    'Shift assignment history',
    'Review effective periods. Assign a new shift from the People directory; close an open period before replacing it.',
    details: {
      'employeeName': 'Employee',
      'shiftName': 'Shift',
      'validFrom': 'Effective from',
      'validTo': 'Effective until',
    },
    actions: [
      CaseAction(
        'identity.assignment.close',
        'Close effective period',
        fields: [
          CaseField(
            'validTo',
            'Last effective day',
            kind: FieldKind.date,
            initial: '@today',
          ),
          reason,
        ],
        when: active,
      ),
    ],
  ),
  CasePanel(
    'identity.company',
    'Company settings',
    'Manage your company identity and work calendar.',
    details: {
      'slug': 'Workspace',
      'timezone': 'Company timezone',
      'locale': 'Language',
    },
    actions: [
      CaseAction(
        'identity.company.edit',
        'Edit company settings',
        fields: [
          name,
          CaseField(
            'timezone',
            'Company timezone',
            kind: FieldKind.choice,
            choices: {'Asia/Phnom_Penh': 'Phnom Penh · UTC+07'},
          ),
          CaseField(
            'locale',
            'Language',
            kind: FieldKind.choice,
            choices: {'en': 'English'},
            initial: 'en',
          ),
        ],
        when: ownerOnly,
      ),
    ],
  ),
  CasePanel(
    'identity.people',
    'People administration',
    'Onboard people, manage reporting relationships and record employment changes.',
    details: {
      'email': 'Work email',
      'department': 'Department',
      'position': 'Position',
      'roles': 'Access roles',
      'hireDate': 'Hire date',
      'invitationStatus': 'Invitation',
    },
    create: CaseAction(
      'identity.employee.create',
      'Add employee',
      fields: [
        name,
        CaseField('email', 'Work email', kind: FieldKind.email),
        CaseField('employeeNo', 'Employee number'),
        CaseField(
          'departmentId',
          'Department',
          kind: FieldKind.lookup,
          lookup: 'identity.departments',
        ),
        CaseField(
          'positionId',
          'Position',
          kind: FieldKind.lookup,
          lookup: 'identity.positions',
        ),
        CaseField(
          'managerId',
          'Manager',
          kind: FieldKind.lookup,
          lookup: 'identity.people',
          required: false,
        ),
        CaseField(
          'hireDate',
          'Hire date',
          kind: FieldKind.date,
          initial: '@today',
        ),
      ],
    ),
    actions: [
      CaseAction(
        'identity.employee.edit',
        'Edit employee',
        fields: [
          name,
          CaseField('email', 'Work email', kind: FieldKind.email),
          CaseField(
            'departmentId',
            'Department',
            kind: FieldKind.lookup,
            lookup: 'identity.departments',
          ),
          CaseField(
            'positionId',
            'Position',
            kind: FieldKind.lookup,
            lookup: 'identity.positions',
          ),
          CaseField(
            'managerId',
            'Manager',
            kind: FieldKind.lookup,
            lookup: 'identity.people',
            required: false,
          ),
        ],
        when: active,
      ),
      CaseAction(
        'identity.employee.invite',
        'Send invitation',
        fields: [reason],
        when: active,
      ),
      CaseAction(
        'identity.employee.roles',
        'Change access role',
        fields: [
          CaseField(
            'role',
            'Access role',
            kind: FieldKind.choice,
            choices: {
              'EMPLOYEE': 'Employee',
              'MANAGER': 'Manager',
              'HR_ADMIN': 'HR administrator',
              'OWNER': 'Company owner',
            },
          ),
          reason,
        ],
        when: ownerOnly,
      ),
      CaseAction(
        'identity.employee.terminate',
        'End employment',
        fields: [
          CaseField(
            'effectiveDate',
            'Last employment day',
            kind: FieldKind.date,
            initial: '@today',
          ),
          reason,
        ],
        when: independent,
        destructive: true,
      ),
    ],
  ),
  CasePanel(
    'identity.sites',
    'Work sites',
    'Manage authorized attendance locations and accuracy requirements.',
    details: {
      'latitude': 'Latitude',
      'longitude': 'Longitude',
      'radiusMeters': 'Site radius (m)',
      'timezone': 'Timezone',
    },
    create: CaseAction(
      'identity.site.create',
      'Add work site',
      fields: [
        name,
        CaseField(
          'latitude',
          'Latitude',
          kind: FieldKind.number,
          minimum: -90,
          maximum: 90,
        ),
        CaseField(
          'longitude',
          'Longitude',
          kind: FieldKind.number,
          minimum: -180,
          maximum: 180,
        ),
        CaseField(
          'radiusMeters',
          'Site radius in meters',
          kind: FieldKind.integer,
          minimum: 10,
          maximum: 10000,
        ),
        CaseField(
          'timezone',
          'Timezone',
          kind: FieldKind.choice,
          choices: {'Asia/Phnom_Penh': 'Phnom Penh · UTC+07'},
          initial: 'Asia/Phnom_Penh',
        ),
      ],
    ),
    actions: [
      CaseAction(
        'identity.site.edit',
        'Edit work site',
        fields: [
          name,
          CaseField(
            'latitude',
            'Latitude',
            kind: FieldKind.number,
            minimum: -90,
            maximum: 90,
          ),
          CaseField(
            'longitude',
            'Longitude',
            kind: FieldKind.number,
            minimum: -180,
            maximum: 180,
          ),
          CaseField(
            'radiusMeters',
            'Site radius in meters',
            kind: FieldKind.integer,
            minimum: 10,
            maximum: 10000,
          ),
        ],
      ),
      CaseAction(
        'identity.site.archive',
        'Archive work site',
        fields: [reason],
        when: active,
        destructive: true,
      ),
    ],
  ),
  CasePanel(
    'identity.shifts',
    'Shift policies',
    'Define hours, working days and grace periods without rewriting finalized attendance.',
    details: {
      'startTime': 'Start time',
      'endTime': 'End time',
      'days': 'Workdays',
      'graceMinutes': 'Arrival grace (min)',
      'earlyToleranceMinutes': 'Departure tolerance (min)',
      'timezone': 'Timezone',
    },
    actions: [
      CaseAction(
        'identity.shift.edit',
        'Edit shift policy',
        fields: [
          name,
          CaseField('startTime', 'Start time', kind: FieldKind.time),
          CaseField('endTime', 'End time', kind: FieldKind.time),
          CaseField(
            'workingDays',
            'Working days',
            kind: FieldKind.weekdays,
            minimum: 1,
            maximum: 127,
            initial: 31,
          ),
          CaseField(
            'graceMinutes',
            'Arrival grace in minutes',
            kind: FieldKind.integer,
            minimum: 0,
            maximum: 120,
            initial: 10,
          ),
          CaseField(
            'earlyToleranceMinutes',
            'Departure tolerance in minutes',
            kind: FieldKind.integer,
            minimum: 0,
            maximum: 120,
            initial: 0,
          ),
          reason,
        ],
      ),
    ],
  ),
  CasePanel(
    'identity.departments',
    'Department administration',
    'Archive unused departments while preserving employment history.',
    details: {'parentName': 'Parent department'},
    actions: [
      CaseAction(
        'identity.department.archive',
        'Archive department',
        fields: [reason],
        when: active,
        destructive: true,
      ),
    ],
  ),
  CasePanel(
    'identity.positions',
    'Position catalog',
    'Available positions for onboarding and employee changes.',
  ),
];
