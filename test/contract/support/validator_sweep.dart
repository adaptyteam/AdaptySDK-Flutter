// The payloads derived from every positive case of the corpus that the contract must reject, and whether the
// validator rejects each one where it was broken.
import 'dart:convert';

import '../../../tool/contract/src/baseline.dart';
import '../../../tool/contract/src/contract_schema.dart';
import '../../../tool/contract/src/corpus.dart';
import '../../../tool/contract/src/json_pointer.dart';
import '../../../tool/contract/src/negative_variants.dart';

/// How a payload is checked; the validator of the schema unless a self-test gives another.
typedef PayloadCheck = List<Violation> Function(SchemaEntry entry, Object? instance, ContractPlatform platform);

/// What a sweep of the corpus found.
final class SweepResult {
  const SweepResult({required this.mutants, required this.missed, required this.withoutMutants});

  /// How many broken payloads were checked, by the kind of the case they come from.
  final Map<CorpusKind, int> mutants;

  /// Every broken payload the check did not reject where it was broken, one line each.
  final List<String> missed;

  /// Every positive case no broken payload could be derived from, one line each.
  final List<String> withoutMutants;

  int get total => mutants.values.fold(0, (a, b) => a + b);
}

/// Derives the broken payloads of every positive case of [corpus] on each platform it is for, and checks that each
/// is rejected at the node it was broken at:
/// - a request (a golden request) as a whole, without the keys the baseline of [corpus] accepts on that platform;
/// - a response by its `success` value, against the branch of the envelope that carries it, so that a broken value
///   is reported at its own node and not only as an envelope no branch matched;
/// - a response by its envelope: without `success` and `error`, and, for a success of an envelope with branches,
///   with an error as well;
/// - an event as a whole.
SweepResult sweepCorpus(ContractSchema schema, Corpus corpus, {PayloadCheck? check}) {
  final validate =
      check ??
      (SchemaEntry entry, Object? instance, ContractPlatform platform) =>
          schema.validate(entry, instance, platform: platform).violations;
  final accepted = baselineItems(corpus.baseline);
  final mutants = {for (final kind in CorpusKind.values) kind: 0};
  final missed = <String>[];
  final withoutMutants = <String>[];

  void sweep(CorpusFixture fixture, ContractPlatform platform, SchemaEntry entry, Iterable<NegativeVariant> variants) {
    for (final variant in variants) {
      mutants[fixture.kind] = mutants[fixture.kind]! + 1;
      final violations = validate(entry, variant.instance, platform);
      if (!violations.any((v) => v.pointsAt(variant.expectedPointer))) {
        missed.add(
          '${fixture.path} on ${platform.name}: $variant'
          '${violations.isEmpty ? ' accepted' : ' rejected elsewhere (${violations.join('; ')})'}',
        );
      }
    }
  }

  for (final fixture in corpus.fixtures) {
    if (fixture.isNegative) continue;
    final known = switch (fixture.kind) {
      CorpusKind.event => schema.eventPlatforms[fixture.name],
      _ => schema.methodPlatforms[fixture.name],
    };
    if (known == null) continue;
    for (final platform in fixture.platform == null ? known : {fixture.platform!}) {
      final where = '${fixture.path} on ${platform.name}';
      final before = mutants[fixture.kind]!;
      try {
        switch (fixture.kind) {
          case CorpusKind.request:
            final entry = schema.requestEntry(fixture.name);
            sweep(
              fixture,
              platform,
              entry,
              negativeVariants(entry, _withoutAccepted(schema, entry, fixture, platform, accepted), platform),
            );
          case CorpusKind.event:
            final entry = schema.eventEntry(fixture.name);
            sweep(fixture, platform, entry, negativeVariants(entry, fixture.payload, platform));
          case CorpusKind.response:
            final envelope = schema.responseEntry(fixture.name);
            final payload = fixture.payload! as Map<String, Object?>;
            if (payload.containsKey('success')) {
              final branch = schema.entryAt(_successBranch(schema, envelope), ValidationMode.responseOpen);
              sweep(fixture, platform, branch, negativeVariants(branch, {'success': payload['success']}, platform));
            }
            sweep(fixture, platform, envelope, [
              NegativeVariant(
                kind: MutantKind.removeRequired,
                instance: const <String, Object?>{},
                instancePath: '',
                expectedPointer: envelope.pointer,
              ),
              if (payload.containsKey('success') &&
                  _hasBranches(schema.resolve(envelope.pointer)! as Map<String, Object?>))
                NegativeVariant(
                  kind: MutantKind.extraKey,
                  instance: {...payload, 'error': _error},
                  instancePath: '',
                  expectedPointer: envelope.pointer,
                ),
            ]);
        }
      } on ArgumentError catch (e) {
        withoutMutants.add('$where: ${e.message}');
        continue;
      }
      if (mutants[fixture.kind] == before) withoutMutants.add('$where: no broken payload can be derived');
    }
  }
  return SweepResult(mutants: mutants, missed: missed, withoutMutants: withoutMutants);
}

/// An error both natives could send, to put next to a success.
const _error = {'adapty_code': 0, 'message': 'an error next to a success'};

/// The branch of the envelope [envelope] that carries `success`; the response itself when it has no branches.
String _successBranch(ContractSchema schema, SchemaEntry envelope) {
  final node = schema.resolve(envelope.pointer)! as Map<String, Object?>;
  if (!_hasBranches(node)) return envelope.pointer;
  for (final combinator in const ['oneOf', 'anyOf']) {
    final branches = node[combinator];
    if (branches is! List<Object?>) continue;
    for (final (i, branch) in branches.indexed) {
      if (((branch! as Map<String, Object?>)['properties'] as Map<String, Object?>?)?.containsKey('success') ?? false) {
        return '${envelope.pointer}/$combinator/$i';
      }
    }
  }
  throw ArgumentError.value(envelope.name, 'envelope', 'has no branch with success');
}

bool _hasBranches(Map<String, Object?> node) => node['oneOf'] is List || node['anyOf'] is List;

/// The payload of the golden request [fixture] on [platform] without the keys the baseline takes away there.
Object? _withoutAccepted(
  ContractSchema schema,
  SchemaEntry entry,
  CorpusFixture fixture,
  ContractPlatform platform,
  List<BaselineItem> accepted,
) {
  final payload = jsonDecode(jsonEncode(fixture.payload));
  return withoutPointers(payload, [
    for (final violation in schema.validate(entry, payload, platform: platform).violations)
      if (accepted.any((item) => item.matches(entry.name, platform, violation))) violation.instancePath,
  ]);
}
