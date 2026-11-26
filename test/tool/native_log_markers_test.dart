// The check of the native log of the probe on iOS finds a defect of the plugin by the messages the plugin logs and by
// the subsystem it logs them under. No test of the SDK runs the plugin, so a message reworded in Swift would let the
// check of a device run miss the defect while all tests pass: the literals are read here.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/l2a/src/native_log.dart';

/// The Swift sources of the iOS plugin, joined.
String _swiftSources() => [
  for (final entity in Directory('ios/adapty_flutter/Sources').listSync(recursive: true))
    if (entity is File && entity.path.endsWith('.swift')) entity.readAsStringSync(),
].join('\n');

void main() {
  final swift = _swiftSources();

  test('the iOS plugin logs as its wrapper under the subsystem the check filters on', () {
    expect(RegExp(r'static let wrapper = Category\(subsystem: "([^"]*)"').allMatches(swift).map((m) => m[1]).toList(), [
      iosWrapperSubsystem,
    ]);
  });

  for (final marker in iosWrapperDefectMarkers) {
    test('the iOS plugin logs "$marker" through its wrapper', () {
      expect(
        RegExp('Log\\.wrapper\\.\\w+\\("${RegExp.escape(marker)}').hasMatch(swift),
        isTrue,
        reason: 'no Log.wrapper call of the Swift sources starts with "$marker"',
      );
    });
  }
}
