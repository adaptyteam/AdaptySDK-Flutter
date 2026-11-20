import '../../../tool/contract/src/contract_schema.dart';

/// A small contract schema for the self-tests of the validator. Each section is YAML with its
/// entries at the first column; they are indented under `$requests`, `$events`, `$defs` and
/// `$assets` here.
ContractSchema tempSchema({
  String requests = '',
  String events = '',
  String defs = '',
  String assets = '',
  ContractOverlays overlays = const ContractOverlays(),
}) => ContractSchema.fromYaml(
  tempSchemaText(requests: requests, events: events, defs: defs, assets: assets),
  overlays: overlays,
);

/// The text of [tempSchema].
String tempSchemaText({String requests = '', String events = '', String defs = '', String assets = ''}) {
  String section(String name, String body) {
    final lines = body.trim().isEmpty ? const <String>[] : body.trimRight().split('\n');
    if (lines.isEmpty) return '$name: {}\n';
    return '$name:\n${lines.map((l) => l.isEmpty ? l : '  $l').join('\n')}\n';
  }

  return [
    r'$schema: "https://json-schema.org/draft/2020-12/schema"',
    r'$id: "https://adapty.io/crossPlatform/0.0.0/schema"',
    'title: "Temporary contract"',
    section(r'$requests', requests),
    section(r'$events', events),
    section(r'$defs', defs),
    section(r'$assets', assets),
  ].join('\n');
}
