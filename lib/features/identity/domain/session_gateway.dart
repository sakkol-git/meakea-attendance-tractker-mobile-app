import 'package:hrflow_mobile/features/identity/domain/models.dart';

abstract interface class SessionGateway {
  bool get isLocal;
  Future<Profile?> restoreSession();
  Future<Profile> login({
    required String tenant,
    required String email,
    required String password,
  });
  Future<Profile> demoLogin(String role);
  Future<void> logout();
  Future<void> resetDemo();
  Future<void> clearCache();
  Stream<bool> get staleChanges;
  Stream<void> get sessionExpired;
}
