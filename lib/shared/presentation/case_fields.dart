import '../../features/identity/domain/models.dart';
import '../domain/cases.dart';
import 'case_page.dart';

const reason = CaseField('reason', 'Reason', kind: FieldKind.note);
const note = CaseField('note', 'Note', kind: FieldKind.note);
const employee = CaseField(
  'employeeId',
  'Employee',
  kind: FieldKind.lookup,
  lookup: 'identity.people',
);
const leaveType = CaseField(
  'leaveTypeId',
  'Leave type',
  kind: FieldKind.lookup,
  lookup: 'leave.policies',
);
const material = CaseField(
  'materialId',
  'Material',
  kind: FieldKind.lookup,
  lookup: 'requests.inventory',
);
const workDate = CaseField(
  'workDate',
  'Work date',
  kind: FieldKind.date,
  initial: '@today',
);
const year = CaseField(
  'year',
  'Accounting year',
  kind: FieldKind.integer,
  initial: '@year',
  minimum: 2020,
  maximum: 2100,
);
const name = CaseField('name', 'Name');
const description = CaseField(
  'description',
  'Description',
  kind: FieldKind.note,
);
bool independent(CaseRecord? row, Profile actor) =>
    actor.administers && row?.values['employeeId'] != actor.id;
bool ownerOnly(CaseRecord? row, Profile actor) => actor.role == 'OWNER';
bool active(CaseRecord? row, Profile actor) =>
    row?.status != 'ARCHIVED' && row?.status != 'TERMINATED';
const requestTypes = {
  'GENERAL': 'General request',
  'MATERIAL': 'Material request',
  'REMOTE_WORK': 'Remote work',
  'LATE_ARRIVAL': 'Late arrival',
  'EARLY_LEAVE': 'Early departure',
};
