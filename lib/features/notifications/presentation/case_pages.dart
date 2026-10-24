import '../../../shared/presentation/case_page.dart';

const notificationsPanels = [
  CasePanel(
    'notifications.devices',
    'Notification devices',
    'Review the devices registered to receive your work updates.',
    access: 'employee',
    details: {
      'platform': 'Platform',
      'registeredAt': 'Registered',
      'lastSeenAt': 'Last active',
    },
    actions: [
      CaseAction(
        'notifications.device.remove',
        'Remove this device',
        destructive: true,
      ),
    ],
  ),
  CasePanel(
    'notifications.delivery',
    'Notification delivery',
    'Delivery and retry status for your own work notifications.',
    access: 'employee',
    details: {
      'channel': 'Channel',
      'createdAt': 'Created',
      'deliveredAt': 'Delivered',
      'message': 'Delivery result',
    },
  ),
];
