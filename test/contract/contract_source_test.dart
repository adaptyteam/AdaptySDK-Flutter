/// The contract copy, its source record and the native pins of the plugin must agree: a schema
/// synced from another iOS revision, a native pin moved without the record, or a sync that lands
/// the copy back in the repository root all show up here.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_source.dart';

/// The schema path as the record states it, read without the code under test. The path is written
/// in the record only, so that a move of the copy is one edit.
final String _schemaFile =
    (jsonDecode(File('contract/CONTRACT_SOURCE').readAsStringSync()) as Map<String, Object?>)['schema_file'] as String;
final String _schemaName = _schemaFile.split('/').last;

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

  test('the record names the schema copy, its iOS ref and the Android versions', () {
    final source = ContractSource.load('.');
    expect(source.schemaFile, startsWith('contract/'));
    expect(source.schemaFile, endsWith('.yaml'));
    expect(source.iosRef, 'release/4.4.1');
    expect(source.androidBom, '4.4.0');
    expect(source.androidCrossplatform, '4.4.0');
    expect(File(source.schemaPath('.')).existsSync(), isTrue);
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
      allOf(startsWith('$_schemaFile has sha256 '), contains('contract/CONTRACT_SOURCE says aea619b8')),
    ]);
  });

  test('a schema of another version is reported by its id', () {
    final root = _copyOfRepo();
    _edit(root, 'contract/CONTRACT_SOURCE', '"schema_version": "4.4.1"', '"schema_version": "4.4.0"');

    expect(contractSourceProblems(root), [
      '$_schemaFile has \$id https://adapty.io/crossPlatform/4.4.1/schema; contract/CONTRACT_SOURCE says version 4.4.0',
    ]);
  });

  test('an iOS pin moved to a tag without updating the record is reported', () {
    final root = _copyOfRepo();
    _edit(root, 'ios/adapty_flutter/Package.swift', 'branch: "release/4.4.1"', 'exact: "4.4.1"');

    expect(contractSourceProblems(root), [
      'ios/adapty_flutter/Package.swift resolves AdaptySDK-iOS at 4.4.1; contract/CONTRACT_SOURCE says release/4.4.1',
    ]);
  });

  test('the comment above the iOS pin is not read as the pin', () {
    final root = _copyOfRepo();
    // The comment of the real file names the tag it will be pinned to; only the package line counts.
    expect(File('$root/ios/adapty_flutter/Package.swift').readAsStringSync(), contains('// `exact: "4.4.1"`'));

    expect(contractSourceProblems(root), isEmpty);
  });

  test('an Android BOM or bridge bump without updating the record is reported', () {
    final root = _copyOfRepo();
    _edit(root, 'android/build.gradle', 'adapty-bom:4.4.0', 'adapty-bom:4.4.1');
    _edit(root, 'android/build.gradle', 'crossplatform:4.4.0', 'crossplatform:4.4.2');

    expect(contractSourceProblems(root), [
      'android/build.gradle uses adapty-bom 4.4.1; contract/CONTRACT_SOURCE says 4.4.0',
      'android/build.gradle uses crossplatform 4.4.2; contract/CONTRACT_SOURCE says 4.4.0',
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
    _edit(root, 'contract/CONTRACT_SOURCE', '"schema_sha256": "aea619b8', '"schema_sha256": "ignored');

    final problems = contractSourceProblems(root);
    expect(problems, contains('$_schemaFile has 30 events; contract/CONTRACT_SOURCE says 29'));
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
