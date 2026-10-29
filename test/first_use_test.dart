import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/app.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/core/protocol.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';

import 'support/workspace_fixture.dart';

class FirstUseSource implements DataSource {
  final calls = <DataRequest>[];
  @override
  String get mode => 'remote';
  @override
  Future<DataResponse> send(DataRequest request) async {
    calls.add(request);
    throw const DataFailure(401, 'UNAUTHENTICATED', 'Sign in required.');
  }

  @override
  void close() {}
}

class FirstUseSettings extends SettingsController {
  @override
  Settings build() => const Settings();
}

void main() {
  testWidgets(
    'remote first use explains administrator-provided access and public help',
    (tester) async {
      final source = FirstUseSource();
      final client = ClientData.forTest(source);
      final container = ProviderContainer(
        overrides: [
          clientProvider.overrideWithValue(client),
          ...testRepositoryOverrides(HrRepository(client)),
          settingsProvider.overrideWith(FirstUseSettings.new),
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
      container.read(routerProvider).go('/setup');
      await tester.pumpAndSettle();
      expect(find.text('Get access to your workspace'), findsOneWidget);
      expect(find.byType(Form), findsNothing);
      await tester.tap(find.text('Sign-in and getting started help'));
      await tester.pumpAndSettle();
      expect(find.text('Help and getting started'), findsOneWidget);
      expect(find.text('What is my workspace?'), findsOneWidget);
      expect(
        source.calls.any(
          (request) => [
            '/tenants',
            '/auth/setup',
            '/auth/forgot-password',
            '/auth/reset-password',
          ].contains(request.path),
        ),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
