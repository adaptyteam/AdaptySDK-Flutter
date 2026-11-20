import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/contract/src/contract_schema.dart';
import '../../../tool/contract/src/contract_source.dart';
import '../../../tool/contract/src/source_refs.dart';

/// The refs of the natives the contract record of this repository is fixed to: the provenance of a golden case and
/// the start of every source that names a native file.
final repositoryRefs = NativeRefs.of(ContractSource.load('.'));

/// Whether the golden cases are written in this run: `ADAPTY_CONTRACT_UPDATE=1`.
final updateGoldenCases = Platform.environment['ADAPTY_CONTRACT_UPDATE'] == '1';

/// What one case has to be on one platform: the payload, written out by hand from the native decoders, and the
/// decoders it follows, which become the notes of the file.
typedef ExpectedCase = ({Map<String, Object?> payload, String notes});

/// The file of the golden case [caseName] under [directory], of [platform] or both platforms share when it is null.
String goldenCasePath(String directory, String caseName, ContractPlatform? platform) =>
    '$directory/$caseName${platform == null ? '' : '.${platform.name}'}.json';

void _write(
  String directory,
  String caseName,
  ContractPlatform? platform,
  Map<String, Object?> payload,
  String notes,
  NativeRefs refs,
) {
  final file = File(goldenCasePath(directory, caseName, platform))..parent.createSync(recursive: true);
  final native = platform == null ? 'both' : refs.of(platform);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({
      'provenance': {'source': 'golden', 'native': native},
      'expect': null,
      'notes': notes,
      'payload': payload,
    })}\n',
  );
}

/// Writes the golden case [caseName] under [directory] from what was [recorded] on each platform: one file both
/// platforms share when the case is [expected] on both, both ran and recorded the same, a file per platform otherwise.
/// A platform that did not run keeps what it had. A payload that is not what [expected] says for its platform is never
/// written: nothing of the case is, and a [StateError] names the case ([name]) and the platform. The file of one
/// platform names its native at the ref [refs] has for it.
void writeGoldenCase({
  required String directory,
  required String name,
  required String caseName,
  required Map<ContractPlatform, ExpectedCase> expected,
  required Map<ContractPlatform, Map<String, Object?>> recorded,
  required NativeRefs refs,
}) {
  for (final MapEntry(key: platform, value: payload) in recorded.entries) {
    final want = expected[platform]?.payload;
    if (want == null || !equals(want).matches(payload, {})) {
      throw StateError('$name on ${platform.name}: the payload is not what the table expects; not written');
    }
  }
  final sendsOn = expected.keys.toSet();
  final shared = File(goldenCasePath(directory, caseName, null));
  final payloads = recorded.values.map(jsonEncode).toSet();
  if (sendsOn.length > 1 && recorded.keys.toSet().containsAll(sendsOn) && payloads.length == 1) {
    for (final platform in ContractPlatform.values) {
      final own = File(goldenCasePath(directory, caseName, platform));
      if (own.existsSync()) own.deleteSync();
    }
    _write(directory, caseName, null, recorded.values.first, expected[sendsOn.first]!.notes, refs);
    return;
  }
  if (shared.existsSync()) {
    final before = (jsonDecode(shared.readAsStringSync()) as Map<String, Object?>)['payload']! as Map<String, Object?>;
    for (final platform in sendsOn.difference(recorded.keys.toSet())) {
      _write(directory, caseName, platform, before, expected[platform]!.notes, refs);
    }
    shared.deleteSync();
  }
  for (final MapEntry(key: platform, value: payload) in recorded.entries) {
    _write(directory, caseName, platform, payload, expected[platform]!.notes, refs);
  }
}
