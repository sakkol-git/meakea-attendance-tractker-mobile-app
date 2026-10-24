class PushRegistration {
  final String token, platform;
  const PushRegistration(this.token, this.platform);
}

abstract interface class PushDevice {
  Future<PushRegistration> enable();
  Stream<PushRegistration> get rotations;
  Stream<Map<String, dynamic>> get opened;
  Future<Map<String, dynamic>?> initialMessage();
}
