import 'package:flutter_test/flutter_test.dart';
import 'package:capstone/services/validation_service.dart';

void main() {
  test('ValidationService.validateEmail returns error for invalid email', () {
    final error = ValidationService.validateEmail('notanemail');
    expect(error, isNotNull);
    final ok = ValidationService.validateEmail('caroline@gmail.com');
    expect(ok, isNull);
  });
} 