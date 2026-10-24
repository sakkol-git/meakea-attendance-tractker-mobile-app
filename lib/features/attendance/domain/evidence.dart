import 'dart:math' as math;

class AttendanceObservation {
  final double latitude, longitude, accuracyMeters;
  final DateTime capturedAt;
  final bool mocked;
  const AttendanceObservation(
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.capturedAt, {
    this.mocked = false,
  });
  Map<String, dynamic> toInput() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracyMeters': accuracyMeters,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'isMocked': mocked,
  };
}

abstract interface class LocationCapture {
  Future<AttendanceObservation> capture();
}

/// A foreground sample can verify an explicitly declared site boundary event.
/// Uncertain samples never claim an inside/outside transition.
bool supportsGeofenceTransition(
  AttendanceObservation observation, {
  required double latitude,
  required double longitude,
  required double radius,
  required bool entering,
}) {
  double rad(double v) => v * math.pi / 180;
  final a =
      math.pow(math.sin(rad(latitude - observation.latitude) / 2), 2) +
      math.cos(rad(latitude)) *
          math.cos(rad(observation.latitude)) *
          math.pow(math.sin(rad(longitude - observation.longitude) / 2), 2);
  final distance = 6371000 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return entering
      ? distance + observation.accuracyMeters <= radius
      : distance - observation.accuracyMeters > radius;
}
