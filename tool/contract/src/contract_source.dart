import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:yaml/yaml.dart';

/// Where the copy of the bridge contract lives in this repository and which native versions it was
/// taken from: `contract/CONTRACT_SOURCE`. The schema path is read from here and nowhere else.
final class ContractSource {
  const ContractSource({
    required this.schemaFile,
    required this.schemaSha256,
    required this.schemaVersion,
    required this.iosRepo,
    required this.iosRef,
    required this.iosSyncedSha,
    required this.androidBom,
    required this.androidCrossplatform,
    required this.requestCount,
    required this.eventCount,
  });

  /// Path of the record relative to the repository root.
  static const recordPath = 'contract/CONTRACT_SOURCE';

  /// Path of the schema copy relative to the repository root.
  final String schemaFile;
  final String schemaSha256;

  /// The version in the schema `$id`.
  final String schemaVersion;
  final String iosRepo;

  /// The iOS ref the plugin builds against: a branch name or a tag.
  final String iosRef;

  /// The iOS commit the schema was copied from.
  final String iosSyncedSha;
  final String androidBom;
  final String androidCrossplatform;
  final int requestCount;
  final int eventCount;

  /// Reads the record of the repository at [repoRoot]. Throws [FormatException] naming the first
  /// field that is missing or has the wrong type.
  static ContractSource load(String repoRoot) {
    final json = jsonDecode(File('$repoRoot/$recordPath').readAsStringSync());
    if (json is! Map<String, Object?>) throw const FormatException('the record is not a JSON object');
    T field<T>(String path) {
      Object? value = json;
      for (final key in path.split('.')) {
        value = value is Map<String, Object?> ? value[key] : null;
      }
      if (value is! T) {
        throw FormatException('$path is missing or not ${T == int ? 'an integer' : 'a string'}');
      }
      return value;
    }

    return ContractSource(
      schemaFile: field<String>('schema_file'),
      schemaSha256: field<String>('schema_sha256'),
      schemaVersion: field<String>('schema_version'),
      iosRepo: field<String>('ios.repo'),
      iosRef: field<String>('ios.ref'),
      iosSyncedSha: field<String>('ios.synced_sha'),
      androidBom: field<String>('android.bom'),
      androidCrossplatform: field<String>('android.crossplatform'),
      requestCount: field<int>('counts.requests'),
      eventCount: field<int>('counts.events'),
    );
  }

  String schemaPath(String repoRoot) => '$repoRoot/$schemaFile';
}

/// Everything in the repository that disagrees with `contract/CONTRACT_SOURCE`, one message per
/// problem; empty when the record, the schema copy and the native pins agree.
List<String> contractSourceProblems(String repoRoot) {
  final ContractSource source;
  try {
    source = ContractSource.load(repoRoot);
  } on FormatException catch (e) {
    return ['${ContractSource.recordPath} cannot be read: ${e.message}'];
  }
  const record = ContractSource.recordPath;
  final problems = <String>[];
  final schemaName = source.schemaFile.split('/').last;
  if (File('$repoRoot/$schemaName').existsSync()) {
    problems.add(
      '$schemaName is in the repository root; the contract copy lives at ${source.schemaFile}: '
      'move it there and update $record',
    );
  }

  final schemaBytes = File(source.schemaPath(repoRoot)).readAsBytesSync();
  final sha = sha256Hex(schemaBytes);
  if (sha != source.schemaSha256) {
    problems.add('${source.schemaFile} has sha256 $sha; $record says ${source.schemaSha256}');
  }
  final schema = loadYaml(utf8.decode(schemaBytes)) as YamlMap;
  final id = schema[r'$id'] as String;
  final idVersion = RegExp(r'/crossPlatform/([^/]+)/schema$').firstMatch(id)?.group(1);
  if (idVersion != source.schemaVersion) {
    problems.add('${source.schemaFile} has \$id $id; $record says version ${source.schemaVersion}');
  }
  final requests = (schema[r'$requests'] as YamlMap).keys.where((k) => (k as String).endsWith('.Request')).length;
  if (requests != source.requestCount) {
    problems.add('${source.schemaFile} has $requests requests; $record says ${source.requestCount}');
  }
  final events = (schema[r'$events'] as YamlMap).length;
  if (events != source.eventCount) {
    problems.add('${source.schemaFile} has $events events; $record says ${source.eventCount}');
  }

  const packageSwift = 'ios/adapty_flutter/Package.swift';
  final iosRef = _iosPackageRef(File('$repoRoot/$packageSwift').readAsStringSync(), source.iosRepo);
  if (iosRef != source.iosRef) {
    problems.add('$packageSwift resolves AdaptySDK-iOS at ${iosRef ?? 'nothing'}; $record says ${source.iosRef}');
  }

  const buildGradle = 'android/build.gradle';
  final gradle = File('$repoRoot/$buildGradle').readAsStringSync();
  for (final (artifact, expected) in [
    ('adapty-bom', source.androidBom),
    ('crossplatform', source.androidCrossplatform),
  ]) {
    final version = RegExp("['\"]io\\.adapty[.a-z]*:$artifact:([^'\"]+)['\"]").firstMatch(gradle)?.group(1);
    if (version != expected) {
      problems.add('$buildGradle uses $artifact ${version ?? 'nothing'}; $record says $expected');
    }
  }
  return problems;
}

/// The branch or tag of the `.package(url: [repo], …)` line, skipping comments. Any other kind of
/// requirement (`from:`, a revision) gives null: the record names a branch or a tag only.
String? _iosPackageRef(String packageSwift, String repo) {
  for (final line in const LineSplitter().convert(packageSwift)) {
    final code = line.trimLeft();
    if (code.startsWith('//') || !code.contains('.package(url: "$repo"')) continue;
    return RegExp(r'\b(?:branch|exact): "([^"]+)"').firstMatch(code)?.group(1);
  }
  return null;
}

/// SHA-256 of [bytes] as lowercase hex (FIPS 180-4).
String sha256Hex(List<int> bytes) {
  const k = <int>[
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, //
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, //
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, //
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, //
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, //
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, //
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, //
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2, //
  ];
  final h = <int>[0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
  int rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xffffffff;

  final paddedLength = ((bytes.length + 9 + 63) ~/ 64) * 64;
  final message = Uint8List(paddedLength)..setRange(0, bytes.length, bytes);
  message[bytes.length] = 0x80;
  final bitLength = bytes.length * 8;
  for (var i = 0; i < 8; i++) {
    message[paddedLength - 1 - i] = (bitLength >> (8 * i)) & 0xff;
  }

  final w = List<int>.filled(64, 0);
  for (var chunk = 0; chunk < paddedLength; chunk += 64) {
    for (var i = 0; i < 16; i++) {
      final o = chunk + i * 4;
      w[i] = (message[o] << 24) | (message[o + 1] << 16) | (message[o + 2] << 8) | message[o + 3];
    }
    for (var i = 16; i < 64; i++) {
      final s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
    }
    var [a, b, c, d, e, f, g, hh] = h;
    for (var i = 0; i < 64; i++) {
      final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      final ch = (e & f) ^ (~e & 0xffffffff & g);
      final t1 = (hh + s1 + ch + k[i] + w[i]) & 0xffffffff;
      final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & 0xffffffff;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & 0xffffffff;
    }
    for (final (i, v) in [a, b, c, d, e, f, g, hh].indexed) {
      h[i] = (h[i] + v) & 0xffffffff;
    }
  }
  return h.map((v) => v.toRadixString(16).padLeft(8, '0')).join();
}
