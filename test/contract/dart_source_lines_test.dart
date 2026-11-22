/// The lines of lib/ a record of the contract names as its source still hold the code the record is about: every
/// `lib/<file>.dart:<lines>` in the records under contract/ (the schema copy aside) has a row below with the
/// identifier of that code, as it is written there — a key, its constant, a type or a value of an enum, the name of
/// an error code — and one of the named lines holds it. A record whose lines move away from the code fails here, and
/// so does a row no record names any more.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The identifier each source in lib/ of the records names, by the source as the records write it.
const _tokens = {
  'lib/src/adapty.dart:217': 'Argument.parameters',
  'lib/src/adapty.dart:433': 'Argument.parameters',
  'lib/src/adapty.dart:702': 'Argument.filter',
  'lib/src/adaptyui.dart:149': 'Argument.enableSafeAreaPaddings',
  'lib/src/adaptyui.dart:159': 'Argument.productPurchaseParameters',
  'lib/src/models/adapty_configuration.dart:24-33': 'AdaptyStoreMessagesHandling',
  'lib/src/models/adapty_error_code.dart:64': 'invalidJson',
  'lib/src/models/adapty_error_code.dart:66': 'pendingPurchase',
  'lib/src/models/adapty_error_code.dart:103': 'receiveRestoredTransactionsFailed',
  'lib/src/models/adapty_profile_parameters.dart:54': 'customAttributes',
  'lib/src/models/private/adapty_configuration_json_builder.dart:38': '_Keys.storeMessagesHandling',
  'lib/src/models/private/adapty_customer_identity_json_builder.dart:5-6': '_Keys.appAccountToken',
  'lib/src/models/private/adapty_flow_ui_schema_json_builder.dart:28-30,38-54': '_Keys.platforms',
  'lib/src/models/private/adapty_flow_ui_schema_json_builder.dart:28-31,38-54': '_Keys.devices',
  'lib/src/models/private/adapty_installation_details_json_builder.dart:41-45': 'internalPluginError',
  'lib/src/models/private/adapty_ios_app_tracking_transparency_status_json_builder.dart:9-18':
      'AdaptyIOSAppTrackingTransparencyStatus.notDetermined',
  'lib/src/models/private/adapty_onboarding_json_builder.dart:10': '_Keys.remoteConfig',
  'lib/src/models/private/adapty_paywall_product_json_builder.dart:22-26': '_Keys.isFamilyShareable',
  'lib/src/models/private/adapty_profile_parameters_json_builder.dart:18': '_Keys.appTrackingTransparencyStatus',
  'lib/src/models/private/adapty_subscription_offer_identifier_json_builder.dart:5': '_Keys.id',
  'lib/src/platform_views/adaptyui_flow_platform_view.dart:160': 'Argument.enableSafeAreaPaddings',
  'lib/src/platform_views/adaptyui_flow_platform_view.dart:175': 'Argument.productPurchaseParameters',
  'lib/src/runtime/bridge.dart:32': 'emptyResult',
  'lib/src/runtime/bridge.dart:57-62': 'internalPluginError',
};

/// A source in lib/ with its lines: `N`, `N-M`, and several of them joined by commas.
final _source = RegExp(r'lib/[A-Za-z0-9_/.-]+\.dart:\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*');

/// Every source in lib/ the records under contract/ name, with the files that name it.
Map<String, Set<String>> _recordSources() {
  final sources = <String, Set<String>>{};
  final files =
      Directory('contract')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.yaml') && !f.path.endsWith('/cross_platform.yaml'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
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

  test('the records name sources in lib/', () {
    expect(sources, isNotEmpty);
  });

  test('every source in lib/ a record names has a row', () {
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
