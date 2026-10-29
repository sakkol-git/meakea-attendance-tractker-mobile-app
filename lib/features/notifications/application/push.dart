export '../domain/notice_route.dart';
import '../../identity/application/session.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/protocol.dart';
import '../domain/push.dart';
import 'providers.dart';

final pushDeviceProvider = Provider<PushDevice>(
  (ref) => throw StateError('Push composition is required.'),
);
final pushRegistrationProvider =
    AsyncNotifierProvider<PushRegistrationController, void>(
      PushRegistrationController.new,
    );

class PushRegistrationController extends AsyncNotifier<void> {
  StreamSubscription<PushRegistration>? subscription;
  @override
  FutureOr<void> build() {
    ref.watch(
      sessionProvider.select((s) => (s.profile?.tenantId, s.profile?.id)),
    );
    ref.onDispose(() => subscription?.cancel());
  }

  Future<void> enable() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final actor = ref.read(sessionProvider).profile;
      final device = ref.read(pushDeviceProvider),
          repository = ref.read(notificationsRepositoryProvider);
      final registration = await device.enable();
      if (!ref.mounted ||
          ref.read(sessionProvider).profile?.id != actor?.id ||
          ref.read(sessionProvider).profile?.tenantId != actor?.tenantId) {
        return;
      }
      await repository.changeCase('notifications.device.register', null, {
        'token': registration.token,
        'platform': registration.platform,
        'name': 'This device',
      }, key: commandKey());
      await subscription?.cancel();
      if (!ref.mounted ||
          ref.read(sessionProvider).profile?.id != actor?.id ||
          ref.read(sessionProvider).profile?.tenantId != actor?.tenantId) {
        return;
      }
      subscription = device.rotations.listen((next) async {
        try {
          if (!ref.mounted ||
              ref.read(sessionProvider).profile?.id != actor?.id ||
              ref.read(sessionProvider).profile?.tenantId != actor?.tenantId) {
            return;
          }
          await repository.changeCase('notifications.device.register', null, {
            'token': next.token,
            'platform': next.platform,
            'name': 'This device',
          }, key: commandKey());
        } catch (e, st) {
          if (ref.mounted) state = AsyncError(e, st);
        }
      });
    });
  }
}

final pushOpenedProvider = StreamProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async* {
  final actor = ref.watch(sessionProvider).profile;
  if (actor == null) return;
  final device = ref.watch(pushDeviceProvider);
  try {
    final first = await device.initialMessage();
    if (!ref.mounted) return;
    if (first != null) yield first;
    yield* device.opened;
  } catch (_) {
    /* An unconfigured push provider does not interrupt the inbox. */
  }
});
