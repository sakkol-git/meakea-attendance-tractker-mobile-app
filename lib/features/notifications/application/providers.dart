import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrflow_mobile/features/notifications/domain/models.dart';
import 'package:hrflow_mobile/core/protocol.dart';

import '../domain/repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => throw StateError('Notifications composition is required.'),
);
final inboxProvider = FutureProvider.autoDispose<List<InboxMessage>>(
  (ref) => ref.watch(notificationsRepositoryProvider).inbox(),
);
final notificationPreferencesProvider = FutureProvider.autoDispose<JsonMap>(
  (ref) async => Map<String, dynamic>.from(
    await ref
        .watch(notificationsRepositoryProvider)
        .get('/notifications/preferences'),
  ),
);
