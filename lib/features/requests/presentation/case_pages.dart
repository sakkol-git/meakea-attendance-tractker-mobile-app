import '../../../shared/presentation/case_page.dart';
import '../../../shared/presentation/case_fields.dart';

const requestsPanels = [
  CasePanel(
    'requests.inventory',
    'Material inventory',
    'Receive stock and inspect remaining availability before issuing materials.',
    details: {
      'unit': 'Unit',
      'stock': 'Available stock',
      'issued': 'Issued quantity',
    },
    actions: [
      CaseAction(
        'requests.stock.receive',
        'Receive stock',
        fields: [
          CaseField(
            'quantity',
            'Quantity received',
            kind: FieldKind.integer,
            minimum: 1,
            maximum: 100000,
          ),
          reason,
        ],
      ),
    ],
  ),
  CasePanel(
    'requests.fulfillment',
    'Material fulfillment',
    'Issue only approved quantities. Partial issues preserve the remaining balance.',
    details: {
      'employeeName': 'Employee',
      'materialName': 'Material',
      'quantity': 'Requested',
      'fulfilledQuantity': 'Already issued',
      'remainingQuantity': 'Remaining',
    },
    actions: [
      CaseAction(
        'requests.issue',
        'Issue materials',
        targetField: 'requestId',
        inherit: ['materialId'],
        fields: [
          CaseField(
            'quantity',
            'Quantity to issue',
            kind: FieldKind.integer,
            minimum: 1,
            maximum: 100000,
          ),
          note,
        ],
        when: independent,
      ),
    ],
  ),
  CasePanel(
    'requests.issues',
    'Material issue history',
    'A history of stock issued to employees.',
    details: {
      'employeeName': 'Employee',
      'materialName': 'Material',
      'quantity': 'Quantity',
      'reason': 'Note',
      'createdAt': 'Issued',
    },
    dates: true,
  ),
  CasePanel(
    'requests.chains',
    'Approval chains',
    'Configure review stages before employees submit. Submitted requests keep their approval snapshot.',
    details: {
      'requestType': 'Request type',
      'requireHr': 'HR review after manager',
      'managerName': 'First reviewer',
    },
    create: CaseAction(
      'requests.chain.create',
      'Add approval chain',
      fields: [
        name,
        CaseField(
          'requestType',
          'Request type',
          kind: FieldKind.lookup,
          lookup: 'requests.types',
          valueField: 'code',
        ),
        CaseField(
          'managerId',
          'First reviewer',
          kind: FieldKind.lookup,
          lookup: 'identity.people',
        ),
        CaseField(
          'requireHr',
          'Require HR review after first reviewer',
          kind: FieldKind.toggle,
          initial: true,
        ),
      ],
    ),
    actions: [
      CaseAction(
        'requests.chain.edit',
        'Edit approval chain',
        fields: [
          name,
          CaseField(
            'managerId',
            'First reviewer',
            kind: FieldKind.lookup,
            lookup: 'identity.people',
          ),
          CaseField(
            'requireHr',
            'Require HR review after first reviewer',
            kind: FieldKind.toggle,
          ),
          reason,
        ],
      ),
    ],
  ),
  CasePanel(
    'requests.types',
    'Request policies',
    'Manage which requests employees may submit and whether supporting evidence is needed.',
    details: {
      'code': 'Request category',
      'requiresAttachment': 'Evidence required',
      'active': 'Available to employees',
    },
    create: CaseAction(
      'requests.type.create',
      'Add request policy',
      fields: [
        name,
        CaseField('code', 'Category code (uppercase letters and underscores)'),
        CaseField(
          'requiresAttachment',
          'Require supporting evidence',
          kind: FieldKind.toggle,
        ),
        CaseField(
          'active',
          'Available to employees',
          kind: FieldKind.toggle,
          initial: true,
        ),
      ],
    ),
    actions: [
      CaseAction(
        'requests.type.edit',
        'Edit request policy',
        fields: [
          name,
          CaseField(
            'requiresAttachment',
            'Require supporting evidence',
            kind: FieldKind.toggle,
          ),
          CaseField('active', 'Available to employees', kind: FieldKind.toggle),
          reason,
        ],
      ),
    ],
  ),
];
