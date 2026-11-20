// What the SDK sends to the native side for every call of the public API: one channel call of the method each case
// names, valid for the platform under the bridge contract and equal to what the native decoders of that platform read
// (test/contract/support/api_calls.dart), and the same as the golden request of the case under contract/requests/.
//
// The golden requests are written with ADAPTY_CONTRACT_UPDATE=1, and the writer refuses a call that is not what the
// table says.
import 'dart:convert';
import 'dart:io';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/constants/method.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/baseline.dart';
import '../../tool/contract/src/contract_schema.dart';
import '../../tool/contract/src/contract_source.dart';
import '../../tool/contract/src/corpus.dart';
import '../../tool/contract/src/overlays.dart' show SchemaFixKind;
import '../../tool/contract/src/source_refs.dart';
import '../support/contract/contract_runtime.dart';
import 'support/api_calls.dart';
import 'support/golden_cases.dart';

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

/// The platforms [call] sends its method on.
Set<ContractPlatform> _sendsOn(ApiCall call) => {
  for (final MapEntry(:key, :value) in call.expected.entries)
    if (value != null) key,
};

/// Writes the golden requests of [call] from what it sent on [recorded] platforms, under the repository at [root] and
/// with the refs of its contract record; see [writeGoldenCase].
void _updateGolden(ApiCall call, Map<ContractPlatform, Map<String, Object?>> recorded, {String root = '.'}) =>
    writeGoldenCase(
      directory: '$root/${Corpus.directory}/${CorpusKind.request.directory}/${call.method}',
      name: call.name,
      caseName: call.caseName,
      expected: {
        for (final platform in _sendsOn(call))
          platform: (payload: call.expected[platform]!.arguments, notes: call.expected[platform]!.source),
      },
      recorded: recorded,
      refs: NativeRefs.of(ContractSource.load(root)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final schema = ContractSchema.load('.');
  final corpus = Corpus.load('.');
  final items = baselineItems(corpus.baseline);
  final accepted = {
    for (final entry in corpus.baseline)
      if (entry.decision == 'accepted') entry.id,
  };

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
    if (!updateGoldenCases) return;
    for (final MapEntry(key: call, value: platforms) in recorded.entries) {
      _updateGolden(call, platforms);
    }
  });

  group('writing the golden requests', () {
    /// A case of `get_profile` that expects [ios] and [android]; a platform without a payload is one it does not
    /// send on when [onAndroid] is false.
    ApiCall expecting({
      Map<String, Object?> ios = const {},
      Map<String, Object?> android = const {},
      bool onAndroid = true,
    }) => ApiCall('get_profile', 'case', (rt) async {}, {
      ContractPlatform.ios: SentRequest(ios, source: 'ios@ref'),
      ContractPlatform.android: onAndroid ? SentRequest(android, source: 'android@ref') : null,
    });

    late String root;
    setUp(() {
      root = Directory.systemTemp.createTempSync('golden_requests_').path;
      addTearDown(() => Directory(root).deleteSync(recursive: true));
      File('$root/${ContractSource.recordPath}')
        ..createSync(recursive: true)
        ..writeAsStringSync(File(ContractSource.recordPath).readAsStringSync());
    });
    Map<String, Object?> files() => {
      if (Directory('$root/contract/requests/get_profile').existsSync())
        for (final file in Directory('$root/contract/requests/get_profile').listSync().whereType<File>())
          file.uri.pathSegments.last: (jsonDecode(file.readAsStringSync()) as Map<String, Object?>)['payload'],
    };

    test('the same request on both platforms is one file both share, and replaces the files of each', () {
      _updateGolden(expecting(ios: {'a': 1}, android: {'a': 2}), {
        ios: {'a': 1},
        android: {'a': 2},
      }, root: root);
      _updateGolden(expecting(ios: {'a': 3}, android: {'a': 3}), {
        ios: {'a': 3},
        android: {'a': 3},
      }, root: root);
      expect(files(), {
        'case.json': {'a': 3},
      });
    });

    test('different requests are a file per platform', () {
      _updateGolden(expecting(ios: {'a': 1}, android: {'a': 2}), {
        ios: {'a': 1},
        android: {'a': 2},
      }, root: root);
      expect(files(), {
        'case.ios.json': {'a': 1},
        'case.android.json': {'a': 2},
      });
    });

    test('writing one platform keeps what the other had, also in a file both shared', () {
      _updateGolden(expecting(ios: {'a': 1}, android: {'a': 1}), {
        ios: {'a': 1},
        android: {'a': 1},
      }, root: root);
      _updateGolden(expecting(ios: {'a': 2}, android: {'a': 1}), {
        ios: {'a': 2},
      }, root: root);
      expect(files(), {
        'case.ios.json': {'a': 2},
        'case.android.json': {'a': 1},
      });
      _updateGolden(expecting(ios: {'a': 2}, android: {'a': 3}), {
        android: {'a': 3},
      }, root: root);
      expect(files(), {
        'case.ios.json': {'a': 2},
        'case.android.json': {'a': 3},
      });
    });

    test('a request sent on one platform only is a file of that platform', () {
      _updateGolden(expecting(ios: {'a': 1}, onAndroid: false), {
        ios: {'a': 1},
      }, root: root);
      expect(files(), {
        'case.ios.json': {'a': 1},
      });
    });

    test('a request that is not what the table expects is not written, nor is the rest of its case', () {
      final call = expecting(ios: {'a': 1}, android: {'a': 2});
      expect(
        () => _updateGolden(call, {
          ios: {'a': 1},
          android: {'a': 9},
        }, root: root),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('get_profile/case'), contains('android')),
          ),
        ),
      );
      expect(files(), isEmpty);
    });

    test('a written file is a golden case of the corpus with the decoders as its notes', () {
      _updateGolden(expecting(ios: {'a': 1}, android: {'a': 2}), {
        ios: {'a': 1},
        android: {'a': 2},
      }, root: root);
      final corpus = Corpus.load(root);
      expect(corpus.problems, isEmpty);
      final written = corpus.fixture(CorpusKind.request, 'get_profile', 'case', android)!;
      expect(written.provenance, {'source': 'golden', 'native': repositoryRefs.android});
      expect(written.notes, 'android@ref');
      expect(written.isNegative, isFalse);
    });

    test('a written file names the native of its platform at the ref of the contract record', () {
      final record = File('$root/${ContractSource.recordPath}');
      final fields = jsonDecode(record.readAsStringSync()) as Map<String, Object?>;
      (fields['ios']! as Map<String, Object?>)['ref'] = '9.9.9';
      (fields['android']! as Map<String, Object?>)['crossplatform'] = '9.9.8';
      record.writeAsStringSync(jsonEncode(fields));

      _updateGolden(expecting(ios: {'a': 1}, android: {'a': 2}), {
        ios: {'a': 1},
        android: {'a': 2},
      }, root: root);

      final corpus = Corpus.load(root);
      expect(corpus.fixture(CorpusKind.request, 'get_profile', 'case', ios)!.provenance['native'], 'ios@9.9.9');
      expect(corpus.fixture(CorpusKind.request, 'get_profile', 'case', android)!.provenance['native'], 'android@9.9.8');
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
          rt.native.expectCase(call.name);

          await call.call(rt);

          final sent = rt.native.calls.where((c) => c.method == call.method).toList();
          if (expected == null) {
            expect(sent, isEmpty, reason: 'the SDK does not send ${call.method} on ${platform.name}');
            return;
          }
          expect(sent, hasLength(1), reason: 'one call of ${call.method}');
          final request = sent.single;
          expect(request.normalizedArguments, expected.arguments);

          // An item of the baseline takes away nothing but in the case it names; what an accepted entry takes away is
          // a key the table says the native of the platform does not act on. Every item that names this case is still
          // there.
          final taken = [
            for (final s in rt.native.suppressed)
              if (identical(s.call, request)) s,
          ];
          for (final s in taken) {
            if (accepted.contains(s.item.id)) {
              expect(expected.ignoredBy[s.violation.instancePath], contains(platform), reason: '${s.item}');
            } else {
              expect(s.item.caseName, call.name, reason: '${s.item} is not for this case');
            }
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

          if (updateGoldenCases) {
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
