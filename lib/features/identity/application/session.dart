import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrflow_mobile/features/identity/domain/models.dart';

import '../domain/session_gateway.dart';

import 'package:hrflow_mobile/app/providers.dart';

final clientProvider = Provider<SessionGateway>(
  (ref) => throw StateError('Session composition is required.'),
);

class SessionState {
  final Profile? profile;
  final bool loading, locked;
  final String? error;
  const SessionState({
    this.profile,
    this.loading = false,
    this.locked = false,
    this.error,
  });
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);

class SessionController extends Notifier<SessionState> {
  int _operation = 0;
  bool _current(int operation) => ref.mounted && operation == _operation;
  @override
  SessionState build() {
    final subscription = ref.read(clientProvider).sessionExpired.listen((_) {
      if (!ref.mounted) return;
      _operation++;
      state = const SessionState(
        error: 'Your session expired. Please sign in again.',
      );
      refreshFeatures(ref);
    });
    ref.onDispose(subscription.cancel);
    Future.microtask(restore);
    return const SessionState(loading: true);
  }

  Future<void> restore() async {
    final operation = ++_operation;
    try {
      final profile = await ref.read(clientProvider).restoreSession();
      if (!_current(operation)) return;
      final locked =
          profile != null &&
          (await ref.read(preferencesProvider).read('hrflow.lock') ?? false);
      if (_current(operation)) {
        state = SessionState(profile: profile, locked: locked);
      }
    } catch (error) {
      if (_current(operation)) state = SessionState(error: message(error));
    }
  }

  Future<void> signIn(String tenant, String email, String password) async {
    final operation = ++_operation;
    state = const SessionState(loading: true);
    try {
      final profile = await ref
          .read(clientProvider)
          .login(tenant: tenant, email: email, password: password);
      if (_current(operation)) state = SessionState(profile: profile);
    } catch (error) {
      if (_current(operation)) state = SessionState(error: message(error));
    }
  }

  Future<void> demo(String role) async {
    final operation = ++_operation;
    try {
      final profile = await ref.read(clientProvider).demoLogin(role);
      if (!_current(operation)) return;
      state = SessionState(profile: profile);
      refreshFeatures(ref);
    } catch (error) {
      if (_current(operation)) state = SessionState(error: message(error));
    }
  }

  void updateProfile(Profile profile) {
    if (state.profile?.id == profile.id &&
        state.profile?.tenantId == profile.tenantId) {
      state = SessionState(profile: profile, locked: state.locked);
    }
  }

  void lock() => state = SessionState(profile: state.profile, locked: true);
  void unlock() => state = SessionState(profile: state.profile);
  Future<void> signOut() async {
    final operation = ++_operation;
    String? error;
    try {
      await ref.read(clientProvider).logout();
    } catch (_) {
      error = 'Signed out on this device. Server revocation could not be confirmed.';
    }
    if (!_current(operation)) return;
    state = SessionState(error: error);
    refreshFeatures(ref);
  }
}
