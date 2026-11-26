import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/contract/src/contract_schema.dart';
import '../../../tool/contract/src/contract_source.dart';
import '../../../tool/contract/src/corpus.dart';
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

/// What the writer puts beside the payload of a golden case that is [expected] on its platforms: in the file of
/// [platform], its native at the ref [refs] has for it and the decoders of that platform; in the file both platforms
/// share (a null [platform]), `both` and the decoders of the first platform of [expected].
({Map<String, Object?> provenance, String notes}) _record(
  ContractPlatform? platform,
  Map<ContractPlatform, ExpectedCase> expected,
  NativeRefs refs,
) => (
  provenance: {'source': 'golden', 'native': platform == null ? 'both' : refs.of(platform)},
  notes: (platform == null ? expected.values.first : expected[platform]!).notes,
);

/// What the golden case [golden] of a case that is [expected] on its platforms has beside its payload that the writer
/// does not put there now, empty when nothing: the writer gives the provenance at the refs of the contract record
/// ([repositoryRefs]) and the decoders as notes, so a case written at other refs, or before its decoders changed, is
/// listed here until the writer runs again.
List<String> writtenRecordProblems(CorpusFixture golden, Map<ContractPlatform, ExpectedCase> expected) {
  final written = _record(golden.platform, expected, repositoryRefs);
  return [
    if (!equals(written.provenance).matches(golden.provenance, {}))
      '${golden.path}: the provenance is ${jsonEncode(golden.provenance)}, the writer writes '
          '${jsonEncode(written.provenance)}; rewrite it with ADAPTY_CONTRACT_UPDATE=1',
    if (golden.notes != written.notes)
      '${golden.path}: the notes are\n  ${golden.notes}\nthe writer writes\n  ${written.notes}\n'
          'rewrite it with ADAPTY_CONTRACT_UPDATE=1',
  ];
}

void _write(
  String directory,
  String caseName,
  ContractPlatform? platform,
  Map<String, Object?> payload,
  Map<ContractPlatform, ExpectedCase> expected,
  NativeRefs refs,
) {
  final file = File(goldenCasePath(directory, caseName, platform))..parent.createSync(recursive: true);
  final record = _record(platform, expected, refs);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'provenance': record.provenance, 'expect': null, 'notes': record.notes, 'payload': payload})}\n',
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
    _write(directory, caseName, null, recorded.values.first, expected, refs);
    return;
  }
  if (shared.existsSync()) {
    final before = (jsonDecode(shared.readAsStringSync()) as Map<String, Object?>)['payload']! as Map<String, Object?>;
    for (final platform in sendsOn.difference(recorded.keys.toSet())) {
      _write(directory, caseName, platform, before, expected, refs);
    }
    shared.deleteSync();
  }
  for (final MapEntry(key: platform, value: payload) in recorded.entries) {
    _write(directory, caseName, platform, payload, expected, refs);
  }
}
