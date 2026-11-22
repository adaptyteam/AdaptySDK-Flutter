/// The contract native before activation against what the plugins answered on a device: every golden request of
/// the bundle of the native probe with an expected reply, of a method whose answer before activation the contract
/// native models, gets from the contract native the same kind of reply with the same code as the probe expects. The
/// probe calls each case before the SDK is activated, as the contract native does after
/// [ContractNative.replyNotActivated].
library;

import 'dart:convert';
import 'dart:io';

import 'package:adapty_flutter/src/runtime/adapty_native_transport.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_schema.dart';
import '../../tool/contract/src/contract_source.dart';
import '../../tool/contract/src/corpus.dart';
import '../../tool/contract/src/source_refs.dart';
import '../../tool/l2a/src/bundle.dart';
import '../support/contract/contract_native.dart';

const _expectationsPath = 'integration_test_app/l2a_expectations.yaml';
const _denylistPath = 'integration_test_app/l2a_denylist.yaml';
const _transportPath = 'lib/src/runtime/adapty_native_transport.dart';
const _methodsPath = 'lib/src/constants/method.dart';

/// The methods compared on each platform. A method that drops out of the model, or out of the golden requests with
/// an expected reply, drops out of the comparison too; this list keeps it from doing so unnoticed.
const _compared = {
  'adapty_ui_create_flow_view',
  'adapty_ui_destroy_flow_view',
  'adapty_ui_dismiss_flow_view',
  'adapty_ui_dismiss_onboarding_view',
  'adapty_ui_present_flow_view',
  'adapty_ui_present_onboarding_view',
  'adapty_ui_send_app_message',
  'adapty_ui_show_dialog',
  'get_current_installation_status',
  'get_flow',
  'get_flow_for_default_audience',
  'get_onboarding',
  'get_profile',
  'identify',
  'is_activated',
  'logout',
  'preload_flows',
  'set_log_level',
  'update_profile',
};

/// The strict bundle of the native probe, built as `tool/l2a/bundle_cases.dart` builds it, with the expectations
/// at [expectationsPath].
L2aBundle _bundle({String expectationsPath = _expectationsPath}) {
  final version = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync());
  final source = ContractSource.load('.');
  return buildBundle(
    schema: ContractSchema.load('.'),
    corpus: Corpus.load('.'),
    views: PlatformViewCases.load('.'),
    sdkMethods: sdkMethodsFrom(File(_methodsPath).readAsStringSync()),
    sdkVersion: version!.group(1)!,
    channelName: channelNameFrom(File(_transportPath).readAsStringSync()),
    denylist: Denylist.parse(File(_denylistPath).readAsStringSync(), path: _denylistPath),
    expectations: Expectations.parse(
      File(expectationsPath).readAsStringSync(),
      path: expectationsPath,
      refs: NativeRefs.of(source).all,
    ),
    androidBom: source.androidBom,
  );
}

/// The golden requests of [platform] with an expected reply, of a method the contract native models before
/// activation.
List<BundleCase> _comparedCases(L2aBundle bundle, ContractPlatform platform) => [
  for (final c in bundle.cases[platform]!)
    if (c.variant == null &&
        (c.expected is ErrorOutcome || c.expected is SuccessOutcome) &&
        ContractNative.modelsBeforeActivation(c.method))
      c,
];

/// A reply as the probe tells replies apart: `success`, or `error <adapty_code>`.
String _kindOf(String? reply) {
  if (reply == null) return 'no reply';
  final decoded = jsonDecode(reply);
  if (decoded is Map<String, Object?>) {
    if (decoded.containsKey('success')) return 'success';
    if (decoded['error'] case {'adapty_code': final int code}) return 'error $code';
  }
  return 'unreadable reply $reply';
}

String _expectedKind(Outcome outcome) => switch (outcome) {
  ErrorOutcome(:final code) => 'error $code',
  SuccessOutcome() => 'success',
  _ => throw ArgumentError.value(outcome, 'outcome', 'not compared'),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bundle = _bundle();

  for (final platform in ContractPlatform.values) {
    group('before activation on ${platform.name}', () {
      final cases = _comparedCases(bundle, platform);

      test('the comparison covers exactly the methods the model and the probe share', () {
        expect(cases.map((c) => c.method).toSet(), _compared);
      });

      for (final c in cases) {
        test('${c.id} answers as the plugin answered the probe', () async {
          final native = ContractNative.install(platform: platform)
            ..replyNotActivated()
            ..expectCase(c.id);

          final reply = await const MethodChannel(adaptyChannelName).invokeMethod<String>(c.method, c.arguments);

          expect(_kindOf(reply), _expectedKind(c.expected));
          expect(native.problems, isEmpty);
        });
      }
    });
  }
}
