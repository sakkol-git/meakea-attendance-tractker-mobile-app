import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/protocol.dart';
import '../domain/push.dart';

class FirebasePushDevice implements PushDevice {
  String get platform => defaultTargetPlatform.name.toUpperCase();
  Future<void> initialize() async {
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      throw const DataFailure(
        0,
        'PUSH_UNSUPPORTED',
        'Push registration is available in the Android and iOS app. Your inbox remains available here.',
      );
    }
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    } catch (_) {
      throw const DataFailure(
        0,
        'PUSH_NOT_CONFIGURED',
        'Push is not configured for this build. Your administrator must connect Firebase and Apple push credentials. Your inbox remains available.',
      );
    }
  }

  @override
  Future<PushRegistration> enable() async {
    await initialize();
    final permission = await FirebaseMessaging.instance.requestPermission();
    if (![
      AuthorizationStatus.authorized,
      AuthorizationStatus.provisional,
    ].contains(permission.authorizationStatus)) {
      throw const DataFailure(
        0,
        'PUSH_DENIED',
        'Notifications were not enabled. You can allow them in device settings.',
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await FirebaseMessaging.instance.getAPNSToken() == null) {
      throw const DataFailure(
        0,
        'PUSH_NOT_READY',
        'Apple notification registration is still pending. Try again shortly.',
      );
    }
    final registration = FirebaseMessaging.instance.onRegistered.first.timeout(
      const Duration(seconds: 30),
    );
    final registered = await Future.wait<Object?>([
      registration,
      FirebaseMessaging.instance.register(),
    ], eagerError: true);
    final token = registered.first as String;
    return PushRegistration(token, platform);
  }

  @override
  Stream<PushRegistration> get rotations => FirebaseMessaging
      .instance
      .onRegistered
      .map((token) => PushRegistration(token, platform));
  @override
  Stream<Map<String, dynamic>> get opened =>
      FirebaseMessaging.onMessageOpenedApp.map((m) => m.data);
  @override
  Future<Map<String, dynamic>?> initialMessage() async {
    await initialize();
    return (await FirebaseMessaging.instance.getInitialMessage())?.data;
  }
}

class DemoPushDevice implements PushDevice {
  @override
  Future<PushRegistration> enable() async =>
      const PushRegistration('fictional-demo-device-token', 'DEMO');
  @override
  Stream<PushRegistration> get rotations => const Stream.empty();
  @override
  Stream<Map<String, dynamic>> get opened => const Stream.empty();
  @override
  Future<Map<String, dynamic>?> initialMessage() async => null;
}
