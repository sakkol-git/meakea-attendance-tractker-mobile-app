import '../../../shared/presentation/case_page.dart';
import '../../../shared/presentation/case_fields.dart';

const shiftEditorFields = <CaseField>[
  name,
  CaseField('startTime', 'Start time', kind: FieldKind.time),
  CaseField('endTime', 'End time', kind: FieldKind.time),
  CaseField(
    'siteId',
    'Work site',
    kind: FieldKind.lookup,
    lookup: 'identity.sites',
  ),
  CaseField(
    'timezone',
    'Timezone',
    kind: FieldKind.choice,
    choices: {'Asia/Phnom_Penh': 'Phnom Penh · UTC+07'},
    initial: 'Asia/Phnom_Penh',
  ),
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
  reason,
];
