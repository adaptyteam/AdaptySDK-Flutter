/// The lines of the plugin a record names as its source still hold the code the record is about: every
/// `lib/<file>.dart:<lines>`, and every line of the iOS and Android host (`ios/adapty_flutter/<file>:<lines>`,
/// `android/src/<file>:<lines>`), in the records under contract/ (the schema copy aside) and in the expectations of
/// integration_test_app/ has a row below with the identifier of that code, as it is written there — a key, its
/// constant, a type or a value of an enum, the name or the value of an error code, a call — and one of the named lines
/// holds it. A record whose lines move away from the code fails here, and so does a row no record names any more.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The identifier each source of the plugin the records name holds, by the source as the records write it.
const _tokens = {
  'android/src/main/kotlin/com/adapty/flutter/AdaptyFlowNativeView.kt:32-34': 'setupFlowView',
  'android/src/main/kotlin/com/adapty/flutter/AdaptyFlowNativeViewFactory.kt:18-24': 'UnsupportedHostFlowView',
  'android/src/main/kotlin/com/adapty/flutter/AdaptyFlowNativeViewFactory.kt:37-57': 'placement_id',
  'android/src/main/kotlin/com/adapty/flutter/AdaptyFlowNativeViewFactory.kt:53': '4001',
  'android/src/main/kotlin/com/adapty/flutter/AdaptyFlutterPlugin.kt:45-46': 'invokeMethod',
  'ios/adapty_flutter/Sources/adapty_flutter/SwiftAdaptyFlutterPlugin.swift:64-67,72': 'setFallbackRequests',
  'ios/adapty_flutter/Sources/adapty_flutter/SwiftAdaptyFlutterPlugin.swift:64-71': 'createPaywallView',
  'ios/adapty_flutter/Sources/adapty_flutter/SwiftAdaptyPaywallNativeView.swift:80-90': 'platformNotSupported',
  'ios/adapty_flutter/Sources/adapty_flutter/SwiftAdaptyPaywallNativeView.swift:129-141': 'FlowViewErrorEvent',
  'ios/adapty_flutter/Sources/adapty_flutter/SwiftAdaptyPaywallNativeView.swift:148-158': 'flow_view_did_receive_error',
  'ios/adapty_flutter/Sources/adapty_flutter/SwiftAdaptyPaywallNativeView.swift:202-207': 'ui',
  'ios/adapty_flutter/Sources/adapty_flutter/SwiftAdaptyPaywallNativeView.swift:221-230': 'placement_id',
  'ios/adapty_flutter/Sources/adapty_flutter/SwiftAdaptyPaywallNativeView.swift:232-241': 'variation_id',
  'lib/src/adapty.dart:231': 'Argument.parameters',
  'lib/src/adapty.dart:447': 'Argument.parameters',
  'lib/src/adapty.dart:718': 'Argument.filter',
  'lib/src/adaptyui.dart:168': 'Argument.enableSafeAreaPaddings',
  'lib/src/adaptyui.dart:178': 'Argument.productPurchaseParameters',
  'lib/src/models/adapty_configuration.dart:24-33': 'AdaptyStoreMessagesHandling',
  'lib/src/models/adapty_error_code.dart:66': 'invalidJson',
  'lib/src/models/adapty_error_code.dart:70': 'pendingPurchase',
  'lib/src/models/adapty_error_code.dart:109': 'receiveRestoredTransactionsFailed',
  'lib/src/models/adapty_profile_parameters.dart:54': 'customAttributes',
  'lib/src/models/private/adapty_configuration_json_builder.dart:38': '_Keys.storeMessagesHandling',
  'lib/src/models/private/adapty_customer_identity_json_builder.dart:5-6': '_Keys.appAccountToken',
  'lib/src/models/private/adapty_flow_ui_schema_json_builder.dart:28-30,38-54': '_Keys.platforms',
  'lib/src/models/private/adapty_flow_ui_schema_json_builder.dart:28-31,38-54': '_Keys.devices',
  'lib/src/models/private/adapty_ios_app_tracking_transparency_status_json_builder.dart:9-18':
      'AdaptyIOSAppTrackingTransparencyStatus.notDetermined',
  'lib/src/models/private/adapty_onboarding_json_builder.dart:10': '_Keys.remoteConfig',
  'lib/src/models/private/adapty_paywall_product_json_builder.dart:22-26': '_Keys.isFamilyShareable',
  'lib/src/models/private/adapty_profile_parameters_json_builder.dart:18': '_Keys.appTrackingTransparencyStatus',
  'lib/src/models/private/adapty_subscription_json_builder.dart:15': '_Keys.vendorTransactionId',
  'lib/src/models/private/adapty_subscription_json_builder.dart:16': '_Keys.vendorOriginalTransactionId',
  'lib/src/models/private/adapty_subscription_offer_identifier_json_builder.dart:5': '_Keys.id',
  'lib/src/platform_views/adaptyui_flow_platform_view.dart:184': 'Argument.enableSafeAreaPaddings',
  'lib/src/platform_views/adaptyui_flow_platform_view.dart:199': 'Argument.productPurchaseParameters',
  'lib/src/runtime/bridge.dart:33': 'emptyResult',
  'lib/src/runtime/bridge.dart:58-63': 'internalPluginError',
};

/// A source of the plugin — a file in lib/, or in the iOS or the Android host — with its lines: `N`, `N-M`, and several
/// of them joined by commas. A path that only ends like one, inside the path of another file, is not one.
final _source = RegExp(
  r'(?<![A-Za-z0-9_./-])'
  r'(?:lib/[A-Za-z0-9_/.-]+\.dart|(?:ios/adapty_flutter|android/src)/[A-Za-z0-9_/.+-]+\.(?:swift|kt|java|m|h))'
  r':\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*',
);

/// Every source of the plugin the records name — the YAML and the fixtures under contract/, the YAML of
/// integration_test_app/ — with the files that name it.
Map<String, Set<String>> _recordSources() {
  final sources = <String, Set<String>>{};
  final files = [
    ...Directory('contract')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (f) => (f.path.endsWith('.yaml') || f.path.endsWith('.json')) && !f.path.endsWith('/cross_platform.yaml'),
        ),
    ...Directory('integration_test_app').listSync().whereType<File>().where((f) => f.path.endsWith('.yaml')),
  ]..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    for (final match in _source.allMatches(file.readAsStringSync())) {
      (sources[match[0]!] ??= {}).add(file.path);
    }
  }
  return sources;
}

/// The lines [source] names, by their number.
Map<int, String> _namedLines(String source) {
  final colon = source.lastIndexOf(':');
  final lines = File(source.substring(0, colon)).readAsLinesSync();
  return {
    for (final part in source.substring(colon + 1).split(','))
      for (var n = int.parse(part.split('-').first); n <= int.parse(part.split('-').last) && n <= lines.length; n++)
        n: lines[n - 1],
  };
}

/// Whether [line] holds [token] as a whole identifier, not as a part of a longer one.
bool _holds(String line, String token) =>
    RegExp('(?<![A-Za-z0-9_])${RegExp.escape(token)}(?![A-Za-z0-9_])').hasMatch(line);

void main() {
  final sources = _recordSources();

  test('the records name sources of the plugin', () {
    expect(sources, isNotEmpty);
  });

  test('every source a record names has a row', () {
    expect({
      for (final MapEntry(:key, :value) in sources.entries)
        if (!_tokens.containsKey(key)) key: value,
    }, isEmpty);
  });

  test('every row is a source a record names', () {
    expect(_tokens.keys.where((source) => !sources.containsKey(source)), isEmpty);
  });

  group('the lines of', () {
    for (final MapEntry(key: source, value: token) in _tokens.entries) {
      test('$source hold $token', () {
        final lines = _namedLines(source);
        expect(
          lines.values.any((line) => _holds(line, token)),
          isTrue,
          reason:
              'no named line holds $token:\n${[for (final MapEntry(:key, :value) in lines.entries) '$key: $value'].join('\n')}',
        );
      });
    }
  });
}
