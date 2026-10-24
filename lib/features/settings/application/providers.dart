import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/preferences_gateway.dart';

class Settings {
  final bool dark, deviceLock;
  const Settings({this.dark = false, this.deviceLock = false});
}

final preferencesProvider = Provider<PreferencesGateway>(
  (ref) => throw StateError('Preferences composition is required.'),
);

final settingsProvider = NotifierProvider<SettingsController, Settings>(
  SettingsController.new,
);

class SettingsController extends Notifier<Settings> {
  @override
  Settings build() {
    Future.microtask(() async {
      final p = ref.read(preferencesProvider);
      final settings = Settings(
        dark: await p.read('hrflow.dark') ?? false,
        deviceLock: await p.read('hrflow.lock') ?? false,
      );
      if (ref.mounted) state = settings;
    });
    return const Settings();
  }

  Future<void> setDark(bool v) async {
    await ref.read(preferencesProvider).write('hrflow.dark', v);
    state = Settings(dark: v, deviceLock: state.deviceLock);
  }

  Future<void> setLock(bool v) async {
    await ref.read(preferencesProvider).write('hrflow.lock', v);
    state = Settings(dark: state.dark, deviceLock: v);
  }
}
