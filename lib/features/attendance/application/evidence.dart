import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/evidence.dart';

final locationCaptureProvider = Provider<LocationCapture>(
  (ref) => throw StateError('Location capture composition is required.'),
);
