/// The corpus of the bridge contract: what Dart sends and what each native answers and emits, one
/// JSON file per case under `contract/{requests,responses,events}/<name>/<case>[.<platform>].json`.
library;

import 'dart:convert';
import 'dart:io';

import 'baseline.dart';
import 'contract_schema.dart';
import 'json_pointer.dart';
import 'overlays.dart' show plainYaml;
import 'schema_validator.dart';

/// A directory of the corpus.
enum CorpusKind {
  request('requests'),
  response('responses'),
  event('events');

  const CorpusKind(this.directory);

  /// The directory under `contract/`.
  final String directory;
}

/// One case of the corpus.
final class CorpusFixture {
  const CorpusFixture({
    required this.kind,
    required this.name,
    required this.caseName,
    required this.platform,
    required this.path,
    required this.provenance,
    required this.expect,
    required this.notes,
    required this.payload,
  });

  final CorpusKind kind;

  /// The method of a request or a response, the id of an event.
  final String name;
  final String caseName;

  /// The platform the file is for; null for a file both platforms share.
  final ContractPlatform? platform;

  /// The path relative to the repository root.
  final String path;
  final Map<String, Object?> provenance;

  /// What a negative case breaks; null for a positive case.
  final Map<String, Object?>? expect;

  /// The native coder the payload follows, as `file:line`.
  final String notes;
  final Object? payload;

  bool get isNegative => expect != null;
}

/// An entry of `contract/baseline/known_discrepancies.yaml`.
final class BaselineEntry {
  const BaselineEntry({required this.id, required this.decision, required this.reason, required this.fields});

  final String id;

  /// `fix_dart`, `ask_native` or `accepted`.
  final String decision;
  final String reason;

  /// Every field of the entry as written.
  final Map<String, Object?> fields;
}

/// The corpus of a repository.
final class Corpus {
  const Corpus({required this.fixtures, required this.baseline, required this.problems});

  /// The fixtures, the baseline and the files that could not be read of the repository at [repoRoot].
  static Corpus load(String repoRoot) {
    final problems = <String>[];
    final fixtures = <CorpusFixture>[];
    final root = Directory('$repoRoot/${Corpus.directory}');
    if (root.existsSync()) {
      for (final entry in _sorted(root.listSync())) {
        final name = _nameOf(entry);
        if (entry is Directory && !name.startsWith('.') && !_directories.contains(name)) {
          problems.add('${Corpus.directory}/$name: not a directory of the contract');
        }
      }
    }
    for (final kind in CorpusKind.values) {
      final kindDirectory = Directory('$repoRoot/${Corpus.directory}/${kind.directory}');
      if (!kindDirectory.existsSync()) continue;
      for (final entry in _sorted(kindDirectory.listSync())) {
        final name = _nameOf(entry);
        if (name.startsWith('.')) continue;
        final relative = '${Corpus.directory}/${kind.directory}/$name';
        if (entry is! Directory) {
          problems.add('$relative: not a directory of cases');
          continue;
        }
        fixtures.addAll(_readCaseDirectory(kind, name, entry, relative, problems));
      }
    }
    return Corpus(fixtures: fixtures, baseline: _readBaseline(repoRoot, problems), problems: problems);
  }

  /// The cases of [name] in [directory] (at [relative] from the repository root), read as [kind]: a
  /// file that does not read, and a file of one platform for a case that has a file both platforms
  /// share, go to [problems] instead.
  static List<CorpusFixture> _readCaseDirectory(
    CorpusKind kind,
    String name,
    Directory directory,
    String relative,
    List<String> problems,
  ) {
    final read = <CorpusFixture>[];
    for (final file in _sorted(directory.listSync())) {
      final fileName = _nameOf(file);
      if (fileName.startsWith('.')) continue;
      final path = '$relative/$fileName';
      try {
        if (file is! File) throw const FormatException('not a file');
        read.add(_readCase(kind, name, fileName, path, file.readAsStringSync()));
      } on FormatException catch (e) {
        problems.add('$path: ${e.message}');
      }
    }
    final shared = {
      for (final c in read)
        if (c.platform == null) c.caseName,
    };
    final cases = <CorpusFixture>[];
    for (final c in read) {
      if (c.platform != null && shared.contains(c.caseName)) {
        problems.add('${c.path}: the case "${c.caseName}" also has a file both platforms share');
      } else {
        cases.add(c);
      }
    }
    return cases;
  }

  /// Of [cases] (the files of one case), the file of [platform], else the file both platforms share.
  static CorpusFixture? _ownElseShared(Iterable<CorpusFixture> cases, ContractPlatform platform) {
    CorpusFixture? shared;
    for (final c in cases) {
      if (c.platform == platform) return c;
      if (c.platform == null) shared = c;
    }
    return shared;
  }

  /// The directory of the corpus relative to the repository root.
  static const directory = 'contract';

  /// The file of the known discrepancies relative to the repository root.
  static const baselinePath = 'contract/baseline/known_discrepancies.yaml';

  /// The directories under `contract/`: the overlays, the baseline and the cases. Its files (the
  /// schema copy and its record) are not the corpus's to check; a name starting with a dot is left
  /// alone everywhere.
  static const _directories = {'overlays', 'baseline', 'requests', 'responses', 'events', 'pseudo'};

  static String _nameOf(FileSystemEntity entity) => entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);

  static List<FileSystemEntity> _sorted(List<FileSystemEntity> entries) =>
      entries..sort((a, b) => a.path.compareTo(b.path));

  static final _fileName = RegExp(r'^([a-z0-9_]+)(?:\.(ios|android))?\.json$');
  static final _rnSample = RegExp(r'^rn-sample@\S+$');
  static const _caseKeys = {'provenance', 'expect', 'notes', 'payload'};

  static CorpusFixture _readCase(CorpusKind kind, String name, String fileName, String path, String text) {
    final match = _fileName.firstMatch(fileName);
    if (match == null) throw const FormatException('not a case file name (<case>[.ios|.android].json)');
    final platform = match[2] == null ? null : ContractPlatform.parse(match[2]!);
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException catch (e) {
      throw FormatException('not JSON (${e.message})');
    }
    if (json is! Map<String, Object?>) throw const FormatException('not a JSON object');
    for (final key in json.keys) {
      if (!_caseKeys.contains(key)) throw FormatException('unknown key "$key"');
    }
    for (final key in _caseKeys) {
      if (!json.containsKey(key)) throw FormatException('$key is missing');
    }
    final provenance = json['provenance'];
    if (provenance is! Map<String, Object?>) throw const FormatException('provenance is not an object');
    for (final key in provenance.keys) {
      if (key != 'source' && key != 'native') throw FormatException('unknown key "provenance.$key"');
    }
    final source = provenance['source'];
    if (source is! String || !(source == 'hand' || source == 'golden' || _rnSample.hasMatch(source))) {
      throw FormatException('provenance.source "$source" is not hand, golden or rn-sample@<tag>');
    }
    final native = provenance['native'];
    final nativeMatches =
        native is String &&
        switch (platform) {
          null => native == 'both',
          final p => native.startsWith('${p.name}@') && native.length > p.name.length + 1,
        };
    if (!nativeMatches) {
      throw FormatException(
        'provenance.native "$native" does not match a file of ${platform?.name ?? 'both platforms'}',
      );
    }
    final notes = json['notes'];
    if (notes is! String || notes.trim().isEmpty) throw const FormatException('notes is not a text');
    final expect = json['expect'];
    if (expect != null) _checkExpect(kind, expect);
    return CorpusFixture(
      kind: kind,
      name: name,
      caseName: match[1]!,
      platform: platform,
      path: path,
      provenance: provenance,
      expect: expect as Map<String, Object?>?,
      notes: notes,
      payload: json['payload'],
    );
  }

  /// A negative request names what the native answers (`native`) or the violation it breaks; a
  /// negative response or event names the violation only, since what Dart does with it is not the
  /// fixture's to say.
  static void _checkExpect(CorpusKind kind, Object expect) {
    if (expect is! Map<String, Object?> || expect.isEmpty) {
      throw const FormatException('expect is neither null nor an object that says what the case breaks');
    }
    if (kind != CorpusKind.request && (expect.length != 1 || !expect.containsKey('violation'))) {
      throw const FormatException('expect of a response or an event is {violation: {keyword, pointer}}');
    }
    for (final MapEntry(:key, :value) in expect.entries) {
      switch (key) {
        case 'native':
          if (value is! String || value.isEmpty) throw const FormatException('expect.native is not a text');
        case 'violation':
          if (value is! Map<String, Object?> ||
              value.length != 2 ||
              value['keyword'] is! String ||
              value['pointer'] is! String) {
            throw const FormatException('expect.violation is not {keyword, pointer}');
          }
        default:
          throw FormatException('unknown key "expect.$key"');
      }
    }
  }

  static const _decisions = ['fix_dart', 'ask_native', 'accepted'];
  static const _baselineKeys = {
    'id',
    'direction',
    'entry',
    'path',
    'keyword',
    'platform',
    'case',
    'items',
    'reason',
    'decision',
    'source',
  };

  static List<BaselineEntry> _readBaseline(String repoRoot, List<String> problems) {
    final file = File('$repoRoot/$baselinePath');
    if (!file.existsSync()) return const [];
    final Object? list;
    try {
      list = plainYaml(file.readAsStringSync());
    } on Exception catch (e) {
      problems.add('$baselinePath: not YAML ($e)');
      return const [];
    }
    if (list == null) return const [];
    if (list is! List<Object?>) {
      problems.add('$baselinePath: not a list of entries');
      return const [];
    }
    final entries = <BaselineEntry>[];
    for (final (index, item) in list.indexed) {
      final where = '$baselinePath entry ${index + 1}';
      if (item is! Map<String, Object?>) {
        problems.add('$where: not a map');
        continue;
      }
      final unknown = item.keys.where((k) => !_baselineKeys.contains(k));
      String? text(String key) =>
          item[key] is String && (item[key] as String).trim().isNotEmpty ? item[key] as String : null;
      final decision = item['decision'];
      final problem = switch (null) {
        _ when unknown.isNotEmpty => 'unknown key "${unknown.first}"',
        _ when text('id') == null => 'id is not a text',
        _ when text('reason') == null => 'reason is not a text',
        _ when !_decisions.contains(decision) =>
          'decision "$decision" is not ${_decisions.take(2).join(', ')} or ${_decisions.last}',
        _ => null,
      };
      if (problem != null) {
        problems.add('$where: $problem');
        continue;
      }
      entries.add(BaselineEntry(id: text('id')!, decision: decision as String, reason: text('reason')!, fields: item));
    }
    return entries;
  }

  final List<CorpusFixture> fixtures;
  final List<BaselineEntry> baseline;

  /// The files that could not be read as fixtures or as the baseline, one line each.
  final List<String> problems;

  /// The case of [platform]: its own file, else the file both platforms share.
  CorpusFixture? fixture(CorpusKind kind, String name, String caseName, ContractPlatform platform) =>
      _ownElseShared(fixtures.where((f) => f.kind == kind && f.name == name && f.caseName == caseName), platform);
}

/// The embedded views of the SDK whose creation parameters the corpus keeps under `contract/pseudo/<view>/`, with the
/// request the native decoders read the parameters as (without its `method`).
const platformViewRequests = {
  'flow_platform_view': 'adapty_ui_create_flow_view',
  'onboarding_platform_view': 'adapty_ui_create_onboarding_view',
};

/// The creation parameters the SDK gives its embedded views, one case per file under
/// `contract/pseudo/<view>/<case>[.ios|.android].json`, in the format of the corpus. They are what the SDK sends, so
/// they are read as requests: [CorpusFixture.kind] is [CorpusKind.request] and [CorpusFixture.name] is the view.
final class PlatformViewCases {
  const PlatformViewCases({required this.cases, required this.problems});

  /// The cases and the files that could not be read of the repository at [repoRoot].
  static PlatformViewCases load(String repoRoot) {
    final problems = <String>[];
    final cases = <CorpusFixture>[];
    final root = Directory('$repoRoot/$directory');
    if (root.existsSync()) {
      for (final entry in Corpus._sorted(root.listSync())) {
        final view = Corpus._nameOf(entry);
        if (view.startsWith('.')) continue;
        final relative = '$directory/$view';
        if (entry is! Directory || !platformViewRequests.containsKey(view)) {
          problems.add('$relative: not an embedded view of the SDK');
          continue;
        }
        cases.addAll(Corpus._readCaseDirectory(CorpusKind.request, view, entry, relative, problems));
      }
    }
    return PlatformViewCases(cases: cases, problems: problems);
  }

  /// The directory of the creation parameters relative to the repository root.
  static const directory = '${Corpus.directory}/pseudo';

  final List<CorpusFixture> cases;

  /// The files that could not be read as cases, one line each.
  final List<String> problems;

  /// The case of [view] for [platform]: its own file, else the file both platforms share.
  CorpusFixture? fixture(String view, String caseName, ContractPlatform platform) =>
      Corpus._ownElseShared(cases.where((c) => c.name == view && c.caseName == caseName), platform);
}

/// The platforms that answer [name] (a request or a response) or emit it (an event), none when the
/// contract does not have it.
Set<ContractPlatform> _platformsOf(ContractSchema schema, CorpusKind kind, String name) =>
    (kind == CorpusKind.event ? schema.eventPlatforms[name] : schema.methodPlatforms[name]) ?? const {};

SchemaEntry _entryOf(ContractSchema schema, CorpusKind kind, String name) => switch (kind) {
  CorpusKind.request => schema.requestEntry(name),
  CorpusKind.response => schema.responseEntry(name),
  CorpusKind.event => schema.eventEntry(name),
};

/// The violations of [payload] against [entry] read in [mode], and when no branch of an envelope (an
/// object whose entry is a `oneOf` or an `anyOf` of `{success}` and `{error}` branches) matched, also the violations
/// of its value against each branch that declares the key, with the key in their paths: a broken
/// value otherwise shows only as a `oneOf` that no branch matched.
List<Violation> _violations(
  ContractSchema schema,
  SchemaEntry entry,
  Object? payload,
  ValidationMode mode,
  ContractPlatform platform,
) {
  final normalized = normalizeJson(payload);
  final whole = schema
      .validate(
        SchemaEntry(schema: schema, name: entry.name, pointer: entry.pointer, mode: mode, method: entry.method),
        normalized,
        platform: platform,
      )
      .violations;
  final envelopeFailed = whole.any((v) => v.instancePath.isEmpty && (v.keyword == 'oneOf' || v.keyword == 'anyOf'));
  if (!envelopeFailed || entry.method != null || normalized is! Map<String, Object?>) return whole;
  final node = schema.resolve(entry.pointer) as Map<String, Object?>;
  final combinator = node.containsKey('oneOf') ? 'oneOf' : 'anyOf';
  final branches = node[combinator];
  if (branches is! List<Object?>) return whole;
  return [
    ...whole,
    for (var i = 0; i < branches.length; i++)
      for (final key in normalized.keys)
        if (((branches[i] as Map<String, Object?>)['properties'] as Map<String, Object?>?)?.containsKey(key) ?? false)
          for (final v in schema.validator.validate(
            normalized[key],
            '${entry.pointer}/$combinator/$i/properties/${escapePointerSegment(key)}',
            mode: mode,
            platform: platform,
          ))
            Violation(
              instancePath: '/${escapePointerSegment(key)}${v.instancePath}',
              keyword: v.keyword,
              schemaPointer: v.schemaPointer,
              via: v.via,
              detail: v.detail,
            ),
  ];
}

/// Everything wrong with the fixtures of [corpus] against [schema], one line each: what could not
/// be read, a fixture of an unknown method or event, of a platform that does not handle the method or
/// send the event, of a method the SDK does not send ([sentMethods]), a positive fixture that is not
/// valid on its platform, and a negative one that is valid or breaks something other than its expect.
/// A request is what the SDK sends, so a violation of a positive request fixture that an item of the
/// baseline of [corpus] takes away on that platform, with the fixture as the case it declares
/// ([takingItem]), is not a problem, as it is not in a call of the SDK.
List<String> fixtureProblems(Corpus corpus, ContractSchema schema, {required Set<String> sentMethods}) {
  final problems = [...corpus.problems];
  final List<BaselineItem> baseline;
  try {
    baseline = baselineItems(corpus.baseline);
  } on FormatException catch (e) {
    return [...problems, '${Corpus.baselinePath}: ${e.message}'];
  }
  final fixtures = [...corpus.fixtures]..sort((a, b) => a.path.compareTo(b.path));
  for (final f in fixtures) {
    final isEvent = f.kind == CorpusKind.event;
    final known = isEvent ? schema.eventIds.contains(f.name) : schema.requestMethods.contains(f.name);
    if (!known) {
      problems.add('${f.path}: the contract has no ${isEvent ? 'event' : 'method'} ${f.name}');
      continue;
    }
    if (!isEvent && !sentMethods.contains(f.name)) {
      problems.add('${f.path}: the SDK does not send ${f.name}');
      continue;
    }
    final handled = _platformsOf(schema, f.kind, f.name);
    if (f.platform != null && !handled.contains(f.platform)) {
      problems.add('${f.path}: ${f.platform!.name} does not ${isEvent ? 'send' : 'handle'} ${f.name}');
      continue;
    }
    final entry = _entryOf(schema, f.kind, f.name);
    for (final platform in ContractPlatform.values) {
      if (f.platform != null ? f.platform != platform : !handled.contains(platform)) continue;
      final violations = [
        for (final v in _violations(schema, entry, f.payload, entry.mode, platform))
          if (f.isNegative ||
              f.kind != CorpusKind.request ||
              takingItem(baseline, entry.name, platform, v, declaredCase: '${f.name}/${f.caseName}') == null)
            v,
      ];
      String listed(List<Violation> v) => v.join('; ');
      if (f.isNegative) {
        final expected = f.expect!['violation'] as Map<String, Object?>?;
        if (violations.isEmpty) {
          problems.add('${f.path}: a negative case, but valid on ${platform.name}');
        } else if (expected != null &&
            !violations.any((v) => v.keyword == expected['keyword'] && v.pointsAt(expected['pointer'] as String))) {
          problems.add(
            '${f.path}: a negative case without ${expected['keyword']} at ${expected['pointer']} '
            'on ${platform.name}: ${listed(violations)}',
          );
        }
      } else if (violations.isNotEmpty) {
        problems.add('${f.path}: not valid on ${platform.name}: ${listed(violations)}');
      } else if (f.kind != CorpusKind.request) {
        final strict = _violations(schema, entry, f.payload, ValidationMode.nativeFixture, platform);
        if (strict.isNotEmpty) problems.add('${f.path}: not what ${platform.name} sends: ${listed(strict)}');
      }
    }
  }
  return problems;
}

/// Every response of a method the SDK sends ([sentMethods]) and every event without a positive
/// `default` case for each platform that answers or emits it, or without a negative case; one line each.
List<String> coverageProblems(Corpus corpus, ContractSchema schema, {required Set<String> sentMethods}) {
  final problems = <String>[];
  void check(CorpusKind kind, String name) {
    for (final platform in ContractPlatform.values) {
      if (!_platformsOf(schema, kind, name).contains(platform)) continue;
      final fixture = corpus.fixture(kind, name, 'default', platform);
      if (fixture == null || fixture.isNegative) {
        problems.add('${Corpus.directory}/${kind.directory}/$name: no positive default for ${platform.name}');
      }
    }
    if (!corpus.fixtures.any((f) => f.kind == kind && f.name == name && f.isNegative)) {
      problems.add('${Corpus.directory}/${kind.directory}/$name: no negative case');
    }
  }

  for (final method in schema.requestMethods) {
    if (sentMethods.contains(method)) check(CorpusKind.response, method);
  }
  for (final id in schema.eventIds) {
    check(CorpusKind.event, id);
  }
  return problems;
}
