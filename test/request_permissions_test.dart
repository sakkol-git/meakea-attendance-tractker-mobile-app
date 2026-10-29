import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/features/identity/data/mappers.dart';

void main() {
  test('native presentation retains explicit grants instead of promoting owner into HR', () {
    final input = {
      'employeeId': 'employee-a',
      'tenantId': 'tenant-a',
      'timeZone': 'Asia/Phnom_Penh',
      'roles': ['OWNER'],
    };
    final owner = ProfileMapper.fromJson(input);
    expect(owner.canReviewRequests, isFalse);
    expect(owner.canFulfillRequests, isFalse);
    final combined = ProfileMapper.fromJson({
      ...input,
      'roles': ['OWNER', 'HR_ADMIN'],
    });
    expect(combined.role, 'OWNER');
    expect(combined.canReviewRequests, isTrue);
    expect(combined.canFulfillRequests, isTrue);
    expect(ProfileMapper.fromJson(input, demo: true).canReviewRequests, isTrue);
  });
}
