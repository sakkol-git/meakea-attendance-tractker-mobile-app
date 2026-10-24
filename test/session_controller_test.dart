import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/app/providers.dart';
import 'package:hrflow_mobile/shared/domain/models.dart';
import 'package:hrflow_mobile/features/identity/domain/session_gateway.dart';

Profile profile(String name) => Profile(
  id: name,
  tenantId: name,
  name: name,
  email: '$name@example.test',
  role: 'EMPLOYEE',
);

class DelayedSession implements SessionGateway {
  final restore = Completer<Profile?>(),
      firstLogin = Completer<Profile>(),
      signedOut = Completer<void>();
  @override
  bool get isLocal => true;
  @override
  Stream<bool> get staleChanges => const Stream.empty();
  @override
  Stream<void> get sessionExpired => const Stream.empty();
  @override
  Future<Profile?> restoreSession() => restore.future;
  @override
  Future<Profile> login({
    required String tenant,
    required String email,
    required String password,
  }) async => tenant == 'first' ? firstLogin.future : profile(tenant);
  @override
  Future<Profile> demoLogin(String role) async => profile(role);
  @override
  Future<void> logout() => signedOut.future;
  @override
  Future<void> resetDemo() async {}
  @override
  Future<void> clearCache() async {}
}

void main() {
  test(
    'late startup restoration cannot replace an explicitly selected account',
    () async {
      final gateway = DelayedSession();
      final container = ProviderContainer(
        overrides: [clientProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      final controller = container.read(sessionProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await controller.demo('new-account');
      gateway.restore.complete(null);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(sessionProvider).profile?.id, 'new-account');
    },
  );
  test(
    'late earlier login and sign-out cannot overwrite a newer successful login',
    () async {
      final gateway = DelayedSession()..restore.complete(null);
      final container = ProviderContainer(
        overrides: [clientProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      final controller = container.read(sessionProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      final first = controller.signIn('first', 'first@example.test', 'fixture');
      await controller.signIn('second', 'second@example.test', 'fixture');
      gateway.firstLogin.complete(profile('first'));
      await first;
      expect(container.read(sessionProvider).profile?.id, 'second');
      final signOut = controller.signOut();
      await controller.signIn('third', 'third@example.test', 'fixture');
      gateway.signedOut.complete();
      await signOut;
      expect(container.read(sessionProvider).profile?.id, 'third');
    },
  );
  test(
    'a late profile edit cannot inject a different account into the session',
    () async {
      final gateway = DelayedSession()..restore.complete(null);
      final container = ProviderContainer(
        overrides: [clientProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      final controller = container.read(sessionProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await controller.signIn('current', 'current@example.test', 'fixture');
      controller.updateProfile(profile('old-account'));
      expect(container.read(sessionProvider).profile?.id, 'current');
    },
  );
}
