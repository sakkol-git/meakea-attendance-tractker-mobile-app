import 'package:geolocator/geolocator.dart';

import '../../../core/protocol.dart';
import '../domain/evidence.dart';

class ForegroundLocationCapture implements LocationCapture {
  @override
  Future<AttendanceObservation> capture() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DataFailure(
        0,
        'LOCATION_DISABLED',
        'Enable location services and try again.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const DataFailure(
        0,
        'LOCATION_DENIED',
        'Location permission was not granted. You can still use manual attendance or request a correction.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return AttendanceObservation(
      position.latitude,
      position.longitude,
      position.accuracy,
      position.timestamp,
      mocked: position.isMocked,
    );
  }
}

class DemoLocationCapture implements LocationCapture {
  @override
  Future<AttendanceObservation> capture() async =>
      AttendanceObservation(11.5564, 104.9282, 15, DateTime.now());
}
