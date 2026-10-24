import '../../../shared/presentation/case_page.dart';

const operationsPanels = [
  CasePanel(
    'operations.readiness',
    'Service readiness',
    'Tenant-scoped service status supplied by your administrator. Worker and model operations run in the secured operations environment.',
    access: 'owner',
    details: {
      'workflow': 'Business workflow',
      'owner': 'Responsible service',
      'message': 'Status details',
      'observedAt': 'Observed',
    },
  ),
];
