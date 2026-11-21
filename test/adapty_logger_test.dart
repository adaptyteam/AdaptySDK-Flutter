import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AdaptyLogger.stamp is four characters from 0-9A-Za-z', () {
    final stamps = List.generate(2000, (_) => AdaptyLogger.stamp);
    expect(stamps, everyElement(matches(RegExp(r'^[0-9A-Za-z]{4}$'))));
    // 8000 characters leave out one of the 62 with a chance of about 2e-55.
    expect(stamps.join().split('').toSet(), hasLength(62));
  });
}
