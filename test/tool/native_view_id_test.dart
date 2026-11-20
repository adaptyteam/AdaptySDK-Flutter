// The plugins build the id of an embedded view themselves, as a literal prefix and the platform view id, and the SDK
// routes the events of the view by that id. No test of the SDK runs the plugins, so a prefix that drifts in Swift or
// Kotlin would send every event of an embedded view to nowhere while all tests pass: the literals are read here.
import 'dart:io';

import 'package:adapty_flutter/src/adaptyui_events_proxy.dart' show adaptyEmbeddedViewIdPrefix;
import 'package:flutter_test/flutter_test.dart';

/// The prefixes of the view ids built in the files under [dir] whose names match [file], by [literal].
List<String> _prefixes(String dir, RegExp file, RegExp literal) => [
  for (final entity in Directory(dir).listSync(recursive: true))
    if (entity is File && file.hasMatch(entity.path))
      for (final match in literal.allMatches(entity.readAsStringSync())) match.group(1)!,
];

void main() {
  test('the iOS plugin builds the id of each embedded view with the prefix the SDK routes by', () {
    final prefixes = _prefixes(
      'ios/adapty_flutter/Sources',
      RegExp(r'\.swift$'),
      RegExp(r'viewId:\s*"([^"\\]*)\\\(viewId\)"'),
    );
    expect(prefixes, hasLength(4), reason: 'the Swift sources build the view id in four places');
    expect(prefixes.toSet(), {adaptyEmbeddedViewIdPrefix});
  });

  test('the Android plugin builds the id of each embedded view with the prefix the SDK routes by', () {
    final prefixes = _prefixes('android/src/main', RegExp(r'NativeView\.kt$'), RegExp(r'"([^"$]*)\$id"'));
    expect(prefixes, hasLength(2), reason: 'the Kotlin sources build the view id in two places');
    expect(prefixes.toSet(), {adaptyEmbeddedViewIdPrefix});
  });
}
