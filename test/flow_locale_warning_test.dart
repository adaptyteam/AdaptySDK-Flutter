/// What the log shows when a flow is fetched with a locale: the locale does nothing for a flow, so the SDK warns once,
/// in full, before the call goes out.
///
/// `AdaptyLogger.logLevel` is static and outlives a test, so every test that changes it restores it.
// The locale is deprecated; passing it is exactly what these tests do.
// ignore_for_file: deprecated_member_use_from_same_package
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/capturing_log_sink.dart';
import 'support/fake_transport.dart';
import 'support/test_runtime.dart';

Map<String, dynamic> _flowJson() => {
  'placement': {
    'developer_id': 'placement-id',
    'audience_name': 'Audience',
    'revision': 1,
    'ab_test_name': 'Experiment',
    'placement_audience_version_id': 'placement-audience-version-id',
  },
  'flow_id': 'flow-id',
  'flow_name': 'Flow',
  'variation_id': 'variation-id',
  'variations': <dynamic>[],
  'response_created_at': 0,
};

/// The two ways to fetch a flow: the name the warning gives the method, its wire name and a fetch with or without
/// a locale.
final _fetches = <(String, String, Future<AdaptyFlow> Function({String? locale}))>[
  ('getFlow', 'get_flow', ({locale}) => Adapty().getFlow(placementId: 'placement-id', locale: locale)),
  (
    'getFlowForDefaultAudience',
    'get_flow_for_default_audience',
    ({locale}) => Adapty().getFlowForDefaultAudience(placementId: 'placement-id', locale: locale),
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CapturingLogSink log;

  void install() {
    final fake = FakeTransport()
      ..reply('get_flow', _flowJson())
      ..reply('get_flow_for_default_audience', _flowJson());
    log = CapturingLogSink();
    installTestRuntime(transport: fake, logSink: log);
  }

  List<(AdaptyLogLevel, String)> warnings() => [
    for (final line in log.lines)
      if (line.$1 == AdaptyLogLevel.warn) line,
  ];

  for (final (name, _, fetch) in _fetches) {
    test('$name with a locale logs one warning saying the locale is ignored and where to pass it', () async {
      install();

      await fetch(locale: 'en');

      expect(warnings(), [
        (
          AdaptyLogLevel.warn,
          'Adapty.$name(locale: "en"): the locale is ignored for flows. '
              'Since Adapty SDK 4.0.0 a flow is localized when its view is built — '
              'pass the locale to AdaptyUI.createFlowView or AdaptyUIFlowPlatformView instead.',
        ),
      ]);
    });

    test('$name without a locale logs no warning', () async {
      install();

      await fetch();

      expect(warnings(), isEmpty);
    });
  }

  for (final (name, wireName, fetch) in _fetches) {
    test('$name logs the locale warning before the line of the outgoing call', () async {
      final savedLogLevel = AdaptyLogger.logLevel;
      addTearDown(() => AdaptyLogger.logLevel = savedLogLevel);
      AdaptyLogger.logLevel = AdaptyLogLevel.verbose;
      install();

      await fetch(locale: 'en');

      final messages = [for (final (_, message) in log.lines) message];
      final warning = messages.indexWhere((message) => message.startsWith('Adapty.$name(locale: "en")'));
      final outgoing = messages.indexWhere((message) => message.contains('--> Adapty.$wireName()'));
      expect(warning, isNonNegative);
      expect(outgoing, isNonNegative);
      expect(warning, lessThan(outgoing));
    });
  }
}
