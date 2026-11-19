/// The contract copy, its source record and the native pins of the plugin must agree: a schema
/// synced from another iOS revision, a native pin moved without the record, or a sync that lands
/// the copy back in the repository root all show up here.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_source.dart';

/// The record as JSON, read without the code under test. The tests take the path and the versions
/// from here, so that a sync, a move of the copy or a native bump changes the record only.
final Map<String, Object?> _record =
    jsonDecode(File('contract/CONTRACT_SOURCE').readAsStringSync()) as Map<String, Object?>;
String _field(String path) => path.split('.').fold<Object?>(_record, (node, key) => (node as Map)[key]).toString();

final String _schemaFile = _field('schema_file');
final String _schemaName = _schemaFile.split('/').last;
final String _iosRepo = _field('ios.repo');

/// The line of Package.swift that requires the iOS SDK.
String _iosPackageLine(String packageSwift) => packageSwift
    .split('\n')
    .singleWhere((line) => !line.trimLeft().startsWith('//') && line.contains('.package(url: "$_iosRepo"'));

final _copiedFiles = [
  'contract/CONTRACT_SOURCE',
  _schemaFile,
  'ios/adapty_flutter/Package.swift',
  'android/build.gradle',
];

/// A copy of the files the record is checked against, in a fresh temporary directory.
String _copyOfRepo() {
  final root = Directory.systemTemp.createTempSync('contract_source_').path;
  addTearDown(() => Directory(root).deleteSync(recursive: true));
  for (final path in _copiedFiles) {
    File('$root/$path')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(File(path).readAsBytesSync());
  }
  return root;
}

void _edit(String root, String path, String from, String to) {
  final file = File('$root/$path');
  final text = file.readAsStringSync();
  expect(text, contains(from), reason: 'the copy of $path no longer has the text this test edits');
  file.writeAsStringSync(text.replaceFirst(from, to));
}

void main() {
  test('the record agrees with the schema copy and the native pins of the plugin', () {
    expect(contractSourceProblems('.'), isEmpty);
  });

  test('the record is read field by field and names the pins of the plugin', () {
    final source = ContractSource.load('.');
    expect(source.schemaFile, allOf(startsWith('contract/'), endsWith('.yaml'), _schemaFile));
    expect(File(source.schemaPath('.')).existsSync(), isTrue);
    expect(
      [source.iosRepo, source.iosRef, source.iosSyncedSha, source.androidBom, source.androidCrossplatform],
      [
        _field('ios.repo'),
        _field('ios.ref'),
        _field('ios.synced_sha'),
        _field('android.bom'),
        _field('android.crossplatform'),
      ],
    );
    expect([
      source.requestCount,
      source.eventCount,
    ], [_field('counts.requests'), _field('counts.events')].map(int.parse));
    final packageLine = _iosPackageLine(File('ios/adapty_flutter/Package.swift').readAsStringSync());
    expect(packageLine, anyOf(contains('branch: "${source.iosRef}"'), contains('exact: "${source.iosRef}"')));
    final gradle = File('android/build.gradle').readAsStringSync();
    expect(gradle, contains('adapty-bom:${source.androidBom}'));
    expect(gradle, contains('crossplatform:${source.androidCrossplatform}'));
  });

  test('a schema copy in the repository root is reported with where it belongs', () {
    final root = _copyOfRepo();
    File('$root/$_schemaFile').copySync('$root/$_schemaName');

    expect(contractSourceProblems(root), [
      '$_schemaName is in the repository root; the contract copy lives at $_schemaFile: '
          'move it there and update contract/CONTRACT_SOURCE',
    ]);
  });

  test('an empty record is reported, not read as defaults', () {
    final root = _copyOfRepo();
    File('$root/contract/CONTRACT_SOURCE').writeAsStringSync('');

    expect(contractSourceProblems(root), [startsWith('contract/CONTRACT_SOURCE cannot be read:')]);
  });

  test('a record without one of its fields is reported with the field name', () {
    final root = _copyOfRepo();
    final record = jsonDecode(File('$root/contract/CONTRACT_SOURCE').readAsStringSync()) as Map<String, Object?>;
    (record['ios'] as Map<String, Object?>).remove('synced_sha');
    File('$root/contract/CONTRACT_SOURCE').writeAsStringSync(jsonEncode(record));

    expect(contractSourceProblems(root), [
      'contract/CONTRACT_SOURCE cannot be read: ios.synced_sha is missing or not a string',
    ]);
  });

  test('a schema synced without updating the record is reported by its hash', () {
    final root = _copyOfRepo();
    _edit(root, _schemaFile, 'title: "Cross Platform Format"', 'title: "Cross Platform Format 2"');

    expect(contractSourceProblems(root), [
      allOf(
        startsWith('$_schemaFile has sha256 '),
        endsWith('contract/CONTRACT_SOURCE says ${_field('schema_sha256')}'),
      ),
    ]);
  });

  test('a schema of another version is reported by its id', () {
    final root = _copyOfRepo();
    final version = _field('schema_version');
    _edit(root, 'contract/CONTRACT_SOURCE', '"schema_version": "$version"', '"schema_version": "0.0.0"');

    expect(contractSourceProblems(root), [
      '$_schemaFile has \$id https://adapty.io/crossPlatform/$version/schema; contract/CONTRACT_SOURCE says version 0.0.0',
    ]);
  });

  for (final requirement in ['exact: "9.9.9"', 'branch: "release/9.9.9"']) {
    test('an iOS pin moved to `$requirement` without updating the record is reported', () {
      final root = _copyOfRepo();
      const path = 'ios/adapty_flutter/Package.swift';
      final line = _iosPackageLine(File('$root/$path').readAsStringSync());
      _edit(root, path, line, line.replaceFirst(RegExp(r'(branch|exact): "[^"]+"'), requirement));

      expect(contractSourceProblems(root), [
        '$path resolves AdaptySDK-iOS at ${requirement.split('"')[1]}; contract/CONTRACT_SOURCE says ${_field('ios.ref')}',
      ]);
    });
  }

  test('a commented-out iOS requirement is not read as the pin', () {
    final root = _copyOfRepo();
    const path = 'ios/adapty_flutter/Package.swift';
    final line = _iosPackageLine(File('$root/$path').readAsStringSync());
    _edit(root, path, line, '        // .package(url: "$_iosRepo", exact: "9.9.9"),\n$line');

    expect(contractSourceProblems(root), isEmpty);
  });

  test('an Android BOM or bridge bump without updating the record is reported', () {
    final root = _copyOfRepo();
    final bom = _field('android.bom'), bridge = _field('android.crossplatform');
    _edit(root, 'android/build.gradle', 'adapty-bom:$bom', 'adapty-bom:9.9.9');
    _edit(root, 'android/build.gradle', 'crossplatform:$bridge', 'crossplatform:9.9.8');

    expect(contractSourceProblems(root), [
      'android/build.gradle uses adapty-bom 9.9.9; contract/CONTRACT_SOURCE says $bom',
      'android/build.gradle uses crossplatform 9.9.8; contract/CONTRACT_SOURCE says $bridge',
    ]);
  });

  test('a request or an event added to the schema shows in the counts', () {
    final root = _copyOfRepo();
    _edit(
      root,
      _schemaFile,
      r'$events:'
          '\n',
      r'$events:'
          '\n  Extra.Event:\n    type: object\n',
    );
    final events = int.parse(_field('counts.events'));

    final problems = contractSourceProblems(root);
    expect(problems, contains('$_schemaFile has ${events + 1} events; contract/CONTRACT_SOURCE says $events'));
    expect(problems.where((p) => p.contains('requests')), isEmpty);
  });

  test('sha256 matches the published test vectors', () {
    expect(sha256Hex(utf8.encode('')), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    expect(sha256Hex(utf8.encode('abc')), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    expect(
      sha256Hex(utf8.encode('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq')),
      '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    );
  });
}
