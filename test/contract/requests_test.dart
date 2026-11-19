// What the SDK sends to the native side for every call of the public API: one channel call of the method each case
// names, valid for the platform under the bridge contract and equal to what the native decoders of that platform read
// (test/contract/support/api_calls.dart), and the same as the golden request of the case under contract/requests/.
//
// The golden requests are written with ADAPTY_CONTRACT_UPDATE=1, and only from a call that is what the table says.
import 'dart:convert';
import 'dart:io';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/constants/method.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/baseline.dart';
import '../../tool/contract/src/contract_schema.dart';
import '../../tool/contract/src/corpus.dart';
import '../../tool/contract/src/overlays.dart' show SchemaFixKind;
import '../support/contract/contract_runtime.dart';
import 'support/api_calls.dart';

/// The rows of the overlays the requests of the SDK still need, and the cases that show it: without the row the
/// request of each case is not valid on the platforms of the row.
const _overlayRowsShownBy = {
  r'#/$defs/AdaptyProfile.CustomAttributes/additionalProperties': ['update_profile/remove_custom_attribute'],
  r'#/$defs/AdaptySubscriptionOffer.Identifier/oneOf/0/properties/id': ['make_purchase/default'],
  r'#/$defs/AdaptyOnboarding/properties/remote_config': ['adapty_ui_create_onboarding_view/without_remote_config'],
  r'#/$defs/AdaptyPaywallProduct.Request/properties/flow_product_id': [
    'make_purchase/default',
    'create_web_paywall_url/product',
    'open_web_paywall/product',
  ],
};

final _update = Platform.environment['ADAPTY_CONTRACT_UPDATE'] == '1';

/// The platforms [call] sends its method on.
Set<ContractPlatform> _sendsOn(ApiCall call) => {
  for (final MapEntry(:key, :value) in call.expected.entries)
    if (value != null) key,
};

String _goldenPath(String root, ApiCall call, ContractPlatform? platform) =>
    '$root/${Corpus.directory}/${CorpusKind.request.directory}/${call.method}/${call.caseName}'
    '${platform == null ? '' : '.${platform.name}'}.json';

void _writeGolden(String root, ApiCall call, ContractPlatform? platform, Map<String, Object?> payload, String notes) {
  final file = File(_goldenPath(root, call, platform))..parent.createSync(recursive: true);
  final native = switch (platform) {
    null => 'both',
    ContractPlatform.ios => 'ios@release/4.4.1',
    ContractPlatform.android => 'android@4.4.0',
  };
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({
      'provenance': {'source': 'golden', 'native': native},
      'expect': null,
      'notes': notes,
      'payload': payload,
    })}\n',
  );
}

/// Writes the golden requests of [call] from what it sent on [recorded] platforms: one file both platforms share when
/// the call sends on both and sends the same, a file per platform otherwise. A platform that did not run keeps what it
/// had. The files go under the repository at [root].
void _updateGolden(ApiCall call, Map<ContractPlatform, Map<String, Object?>> recorded, {String root = '.'}) {
  final sendsOn = _sendsOn(call);
  final shared = File(_goldenPath(root, call, null));
  final payloads = recorded.values.map(jsonEncode).toSet();
  if (sendsOn.length > 1 && recorded.keys.toSet().containsAll(sendsOn) && payloads.length == 1) {
    for (final platform in ContractPlatform.values) {
      final own = File(_goldenPath(root, call, platform));
      if (own.existsSync()) own.deleteSync();
    }
    _writeGolden(root, call, null, recorded.values.first, call.expected[sendsOn.first]!.source);
    return;
  }
  if (shared.existsSync()) {
    final before = (jsonDecode(shared.readAsStringSync()) as Map<String, Object?>)['payload']! as Map<String, Object?>;
    for (final platform in sendsOn.difference(recorded.keys.toSet())) {
      _writeGolden(root, call, platform, before, call.expected[platform]!.source);
    }
    shared.deleteSync();
  }
  for (final MapEntry(key: platform, value: payload) in recorded.entries) {
    _writeGolden(root, call, platform, payload, call.expected[platform]!.source);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final schema = ContractSchema.load('.');
  final corpus = Corpus.load('.');
  final items = baselineItems(corpus.baseline);

  /// The schema without the overlay row at [pointer], for each row, read once.
  final withoutRow = <String, ContractSchema>{};
  ContractSchema schemaWithout(String pointer) => withoutRow[pointer] ??= ContractSchema.fromYaml(
    schema.text,
    overlays: ContractOverlays(
      platformRequired: schema.overlays.platformRequired,
      platformFields: schema.overlays.platformFields,
      platformMethods: schema.overlays.platformMethods,
      lenientRequired: schema.overlays.lenientRequired,
      nullable: [...schema.overlays.nullable.where((r) => r.pointer != pointer)],
      schemaFixes: [...schema.overlays.schemaFixes.where((r) => r.pointer != pointer)],
      noNegativeVariants: schema.overlays.noNegativeVariants,
    ),
  );
  Set<ContractPlatform> rowPlatforms(String pointer) => {
    for (final row in schema.overlays.nullable)
      if (row.pointer == pointer) ...row.platforms,
    for (final row in schema.overlays.schemaFixes)
      if (row.pointer == pointer) ...row.platforms,
  };

  final recorded = <ApiCall, Map<ContractPlatform, Map<String, Object?>>>{};

  late AdaptyLogLevel logLevel;
  setUp(() {
    // activate and setLogLevel change the level of the logger, which activate sends.
    logLevel = AdaptyLogger.logLevel;
    AdaptyLogger.logLevel = AdaptyLogLevel.info;
  });
  tearDown(() => AdaptyLogger.logLevel = logLevel);

  tearDownAll(() {
    if (!_update) return;
    for (final MapEntry(key: call, value: platforms) in recorded.entries) {
      _updateGolden(call, platforms);
    }
  });

  group('writing the golden requests', () {
    final both = ApiCall('get_profile', 'case', (rt) async {}, {
      ios: const SentRequest({}, source: 'ios@ref'),
      android: const SentRequest({}, source: 'android@ref'),
    });
    final iosOnly = ApiCall('get_profile', 'case', (rt) async {}, {
      ios: const SentRequest({}, source: 'ios@ref'),
      android: null,
    });

    late String root;
    setUp(() {
      root = Directory.systemTemp.createTempSync('golden_requests_').path;
      addTearDown(() => Directory(root).deleteSync(recursive: true));
    });
    Map<String, Object?> files() => {
      for (final file in Directory('$root/contract/requests/get_profile').listSync().whereType<File>())
        file.uri.pathSegments.last: (jsonDecode(file.readAsStringSync()) as Map<String, Object?>)['payload'],
    };

    test('the same request on both platforms is one file both share, and replaces the files of each', () {
      _updateGolden(both, {
        ios: {'a': 1},
        android: {'a': 2},
      }, root: root);
      _updateGolden(both, {
        ios: {'a': 3},
        android: {'a': 3},
      }, root: root);
      expect(files(), {
        'case.json': {'a': 3},
      });
    });

    test('different requests are a file per platform', () {
      _updateGolden(both, {
        ios: {'a': 1},
        android: {'a': 2},
      }, root: root);
      expect(files(), {
        'case.ios.json': {'a': 1},
        'case.android.json': {'a': 2},
      });
    });

    test('writing one platform keeps what the other had, also in a file both shared', () {
      _updateGolden(both, {
        ios: {'a': 1},
        android: {'a': 1},
      }, root: root);
      _updateGolden(both, {
        ios: {'a': 2},
      }, root: root);
      expect(files(), {
        'case.ios.json': {'a': 2},
        'case.android.json': {'a': 1},
      });
      _updateGolden(both, {
        android: {'a': 3},
      }, root: root);
      expect(files(), {
        'case.ios.json': {'a': 2},
        'case.android.json': {'a': 3},
      });
    });

    test('a request sent on one platform only is a file of that platform', () {
      _updateGolden(iosOnly, {
        ios: {'a': 1},
      }, root: root);
      expect(files(), {
        'case.ios.json': {'a': 1},
      });
    });

    test('a written file is a golden case of the corpus with the decoders as its notes', () {
      _updateGolden(both, {
        ios: {'a': 1},
        android: {'a': 2},
      }, root: root);
      final corpus = Corpus.load(root);
      expect(corpus.problems, isEmpty);
      final written = corpus.fixture(CorpusKind.request, 'get_profile', 'case', android)!;
      expect(written.provenance, {'source': 'golden', 'native': 'android@4.4.0'});
      expect(written.notes, 'android@ref');
      expect(written.isNegative, isFalse);
    });
  });

  group('the table', () {
    test('every method of the bridge is sent by a case', () {
      final sent = {
        for (final call in apiCalls)
          if (_sendsOn(call).isNotEmpty) call.method,
      };
      expect(NativeMethod.values.map((m) => m.wireName).where((m) => !sent.contains(m)), isEmpty);
    });

    test('every case has a name of its own and runs on at least one platform', () {
      final names = apiCalls.map((call) => call.name).toList();
      expect(names.toSet(), hasLength(names.length));
      for (final call in apiCalls) {
        expect(call.platforms, isNotEmpty, reason: call.name);
      }
    });

    test('a case names the decoders of every platform it sends on', () {
      for (final call in apiCalls) {
        for (final platform in _sendsOn(call)) {
          expect(
            call.expected[platform]!.source,
            contains('${platform.name}@'),
            reason: '${call.name} on ${platform.name}',
          );
        }
      }
    });

    test('every item of the baseline names a case of the table that sends on its platform, or a platform view', () {
      final cases = {for (final call in apiCalls) call.name: _sendsOn(call)};
      for (final item in items) {
        if (item.caseName.startsWith('pseudo/')) continue;
        expect(cases[item.caseName], contains(item.platform), reason: '$item');
      }
    });

    test(
      'every row that lets a request carry null, and every property a schema fix adds to a request, has its cases',
      () {
        final requestFixes = {
          for (final row in schema.overlays.schemaFixes)
            if (row.kind == SchemaFixKind.addProperty && row.pointer.contains('.Request/')) row.pointer,
        };
        expect(_overlayRowsShownBy.keys.toSet(), {...schema.overlays.nullable.map((r) => r.pointer), ...requestFixes});
        final cases = {for (final call in apiCalls) call.name: _sendsOn(call)};
        for (final MapEntry(key: pointer, value: names) in _overlayRowsShownBy.entries) {
          for (final name in names) {
            expect(cases[name]?.intersection(rowPlatforms(pointer)), isNotEmpty, reason: '$pointer: $name');
          }
        }
      },
    );

    test('every golden request is a case of the table on a platform it sends on', () {
      final cases = {for (final call in apiCalls) call.name: _sendsOn(call)};
      final methods = NativeMethod.values.map((m) => m.wireName).toSet();
      for (final fixture in corpus.fixtures) {
        if (fixture.kind != CorpusKind.request || !methods.contains(fixture.name)) continue;
        final name = '${fixture.name}/${fixture.caseName}';
        expect(cases.keys, contains(name), reason: fixture.path);
        if (fixture.platform != null) expect(cases[name], contains(fixture.platform), reason: fixture.path);
      }
    });
  });

  test('activate sends the version of the package as the version of the cross-platform SDK', () async {
    final rt = installContractRuntime(platform: ContractPlatform.ios);
    final version = RegExp(r'^version: (\S+)$', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!;

    await Adapty().activate(configuration: AdaptyConfiguration(apiKey: 'public-key'));

    final configuration = rt.native.calls.single.arguments['configuration']! as Map<String, Object?>;
    expect(configuration['cross_platform_sdk_version'], version.group(1));
    expect(configuration['cross_platform_sdk_name'], 'flutter');
  });

  group('each case', () {
    for (final call in apiCalls) {
      for (final MapEntry(key: platform, value: expected) in call.expected.entries) {
        test('${call.name} on ${platform.name}', () async {
          final rt = installContractRuntime(platform: platform);

          await call.call(rt);

          final sent = rt.native.calls.where((c) => c.method == call.method).toList();
          if (expected == null) {
            expect(sent, isEmpty, reason: 'the SDK does not send ${call.method} on ${platform.name}');
            return;
          }
          expect(sent, hasLength(1), reason: 'one call of ${call.method}');
          final request = sent.single;
          expect(request.normalizedArguments, expected.arguments);

          // What the baseline takes away is a key the table says the native of the platform does not act on, and
          // every item that names this case is still there.
          final taken = [
            for (final s in rt.native.suppressed)
              if (identical(s.call, request)) s,
          ];
          for (final s in taken) {
            expect(expected.ignoredBy[s.violation.instancePath], contains(platform), reason: '${s.item}');
          }
          final shown = taken.map((s) => '${s.item}').toSet();
          for (final item in items.where((i) => i.caseName == call.name && i.platform == platform)) {
            expect(shown, contains('$item'), reason: 'the baseline item is not shown by its case any more');
          }

          // The overlay rows this case shows are still needed: without one the request is not valid.
          final entry = schema.requestEntry(call.method);
          final valid = schema.validate(entry, request.arguments, platform: platform).violations.map((v) => '$v');
          for (final MapEntry(key: pointer, value: names) in _overlayRowsShownBy.entries) {
            if (!names.contains(call.name) || !rowPlatforms(pointer).contains(platform)) continue;
            final without = schemaWithout(
              pointer,
            ).validate(schemaWithout(pointer).requestEntry(call.method), request.arguments, platform: platform);
            expect(
              without.violations.map((v) => '$v').where((v) => !valid.contains(v)),
              isNotEmpty,
              reason: '$pointer is not needed by ${call.name} any more',
            );
          }

          if (_update) {
            (recorded[call] ??= {})[platform] = request.normalizedArguments;
            return;
          }
          final golden = corpus.fixture(CorpusKind.request, call.method, call.caseName, platform);
          expect(golden, isNotNull, reason: 'no golden request; write it with ADAPTY_CONTRACT_UPDATE=1');
          expect(golden!.payload, request.normalizedArguments, reason: golden.path);
        });
      }
    }
  });
}
