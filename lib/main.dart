import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hrflow_mobile/app.dart';
import 'package:hrflow_mobile/app/configuration.dart';
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
    const dataSource = String.fromEnvironment(
      'DATA_SOURCE',
      defaultValue: 'local',
    );
    const allowDemoRelease = bool.fromEnvironment('ALLOW_DEMO_RELEASE');
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
    validateClientConfiguration(
      release: kReleaseMode,
      dataSource: dataSource,
      allowDemoRelease: allowDemoRelease,
      apiBaseUrl: apiBaseUrl,
    );
    final client = await ClientData.create(
      mode: dataSource,
      apiBaseUrl: apiBaseUrl,
    );
    runApp(
      DevicePreview(
        enabled: !kReleaseMode,
        builder: (context) => ProviderScope(
          overrides: composeFeatures(client),
          child: const HrFlowApp(),
        ),
      ),
    );
  } catch (_) {
    runApp(
      DevicePreview(
        enabled: !kReleaseMode,
        builder: (context) => MaterialApp(
          locale: DevicePreview.locale(context),
          builder: DevicePreview.appBuilder,
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
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
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
      ),
    );
  }
}
