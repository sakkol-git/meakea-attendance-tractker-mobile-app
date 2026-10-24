import 'package:hrflow_mobile/core/protocol.dart';

import '../domain/models.dart';
import '../domain/repository.dart';

/// Calendar dates are inclusive. Production authorization/overlap checks belong to the server.
class ShiftUseCases {
  final IdentityRepository repository;
  ShiftUseCases(this.repository);
  static bool validDate(String value) {
    final parsed = DateTime.tryParse(value);
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
        parsed != null &&
        parsed.toIso8601String().substring(0, 10) == value;
  }

  Future<ShiftAssignment> assign(
    Profile actor,
    String employeeId,
    String shiftId,
    String from,
    String? to,
    String key,
  ) {
    if (!actor.administers) {
      throw const DataFailure(403, 'FORBIDDEN', 'HR access is required.');
    }
    if (employeeId.isEmpty ||
        shiftId.isEmpty ||
        !validDate(from) ||
        (to != null && (!validDate(to) || to.compareTo(from) < 0))) {
      throw const DataFailure(
        422,
        'VALIDATION_ERROR',
        'Choose a shift and a valid effective date range.',
      );
    }
    return repository.assignShift(employeeId, shiftId, from, to, key);
  }
}
