import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/app.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/data/storage.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/features/notifications/domain/models.dart';

import 'support/workspace_fixture.dart';

class InboxRepository extends HrRepository {
  InboxRepository(super.client);
  final messages = <InboxMessage>[
    const InboxMessage(
      'known',
      'Leave approved',
      'Your leave was approved.',
      false,
      'leave-pending',
      'leave',
    ),
    const InboxMessage(
      'legacy',
      'Company update',
      'An older notice without a supported record.',
      true,
      null,
      'legacy',
    ),
  ];
  @override
  Future<List<InboxMessage>> inbox() async => messages;
}

class InboxSettings extends SettingsController {
  @override
  Settings build() => const Settings();
}

void main() {
  testWidgets(
    'unread filtering has a clear recovery and legacy notices explain their destination',
    (tester) async {
      final client = await ClientData.create(
        secrets: MemorySecrets(),
        persistDemo: false,
      );
      final repository = InboxRepository(client);
      final container = ProviderContainer(
        overrides: [
          clientProvider.overrideWithValue(client),
          ...testRepositoryOverrides(repository),
          settingsProvider.overrideWith(InboxSettings.new),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HrFlowApp(),
        ),
      );
      await tester.pumpAndSettle();
      await container.read(sessionProvider.notifier).demo('EMPLOYEE');
      container.read(routerProvider).go('/notifications');
      await tester.pumpAndSettle();
      expect(
        find.text('No linked record is available for this update.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Unread only'));
      await tester.pumpAndSettle();
      expect(find.text('Leave approved'), findsOneWidget);
      expect(find.text('Company update'), findsNothing);
      repository.messages.clear();
      container.invalidate(inboxProvider);
      await tester.pumpAndSettle();
      expect(find.text('No unread updates'), findsOneWidget);
      await tester.tap(find.text('Show all updates'));
      await tester.pumpAndSettle();
      expect(find.text('All quiet for now'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
