import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hrflow_mobile/app.dart';
import 'package:hrflow_mobile/core/theme.dart';
import 'package:hrflow_mobile/features/identity/data/session_client.dart';
import 'package:hrflow_mobile/app/composition.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Kantumruy Pro',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  try {
    final client = await ClientData.create();
    runApp(
      ProviderScope(
        overrides: composeFeatures(client),
        child: const HrFlowApp(),
      ),
    );
  } catch (_) {
    runApp(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.settings_outlined, size: 48),
                  const SizedBox(height: 20),
                  const Text(
                    'Workspace could not open',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Check the data-source configuration or device storage, then reopen HRFlow. Your session and demo data have not been replaced.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
