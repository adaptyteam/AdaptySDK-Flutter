// The generated kids package builds its iOS part from tool/kids/Package.swift instead of the package of the plugin, so
// a move of the iOS SDK in one file alone would ship the kids variant on another iOS SDK than the main package.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The requirement on the iOS SDK in the Swift package [text] (`branch: "…"`, `exact: "…"` and so on, spaces
/// collapsed), or null without one.
String? _iosSdkRequirement(String text) => RegExp(
  r'url:\s*"https://github\.com/adaptyteam/AdaptySDK-iOS\.git",\s*(\w+:\s*"[^"]+")',
).firstMatch(text)?[1]?.replaceAll(RegExp(r'\s+'), ' ');

void main() {
  test('the kids package requires the same iOS SDK as the plugin, with the kids mode on', () {
    final plugin = File('ios/adapty_flutter/Package.swift').readAsStringSync();
    final kids = File('tool/kids/Package.swift').readAsStringSync();

    expect(_iosSdkRequirement(plugin), isNotNull);
    expect(_iosSdkRequirement(kids), _iosSdkRequirement(plugin));
    expect(kids, matches(RegExp(r'traits:\s*\[\s*"KidsMode"\s*\]')));
    expect(plugin, isNot(contains('KidsMode')));
  });
}
