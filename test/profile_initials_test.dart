import 'package:flutter_test/flutter_test.dart';
import 'package:hrflow_mobile/core/presentation_format.dart';

void main() {
  test('profile initials tolerate whitespace and empty names', () {
    expect(personInitials('Sok Dara'), 'SD');
    expect(personInitials('  Sok   Dara  '), 'SD');
    expect(personInitials('Sok\tDara'), 'SD');
    expect(personInitials('   '), '');
    expect(personInitials('Sok'), 'S');
  });
}
