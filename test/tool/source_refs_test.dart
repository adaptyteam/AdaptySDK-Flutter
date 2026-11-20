// The refs of the natives a contract record is fixed to, and the refs a source names that are not those.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_schema.dart';
import '../../tool/contract/src/contract_source.dart';
import '../../tool/contract/src/source_refs.dart';

const _refs = NativeRefs(ios: 'ios@release/9.9.9', android: 'android@9.9.9');

void main() {
  test('the refs of a record are the iOS ref and the version of the crossplatform library', () {
    final root = Directory.systemTemp.createTempSync('native_refs_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/${ContractSource.recordPath}')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(_withRefs(File(ContractSource.recordPath).readAsStringSync())));

    final refs = NativeRefs.of(ContractSource.load(root.path));

    expect((refs.ios, refs.android), ('ios@9.9.9', 'android@9.9.8'));
    expect(refs.of(ContractPlatform.ios), 'ios@9.9.9');
    expect(refs.of(ContractPlatform.android), 'android@9.9.8');
  });

  group('a source that names files of the Flutter plugin', () {
    late String root;
    setUp(() {
      root = Directory.systemTemp.createTempSync('plugin_sources_').path;
      addTearDown(() => Directory(root).deleteSync(recursive: true));
      for (final path in ['ios/adapty_flutter/Sources/adapty_flutter/P.swift', 'android/src/main/kotlin/F.kt']) {
        File('$root/$path')
          ..createSync(recursive: true)
          ..writeAsStringSync('one\ntwo\nthree\n');
      }
    });

    List<String> problems(String source) =>
        sourceProblems('why', source, refs: {'ios@release/9.9.9', 'android@9.9.9'}, root: root);

    test('has no problem when the files are there with the lines it names, next to a native file', () {
      expect(
        problems(
          'ios@release/9.9.9 Sources/A.swift:4; ios/adapty_flutter/Sources/adapty_flutter/P.swift:1-3; '
          'android/src/main/kotlin/F.kt:2',
        ),
        isEmpty,
      );
    });

    test('has a problem for a file of the plugin that is not there or has fewer lines than it names', () {
      expect(problems('ios/adapty_flutter/Sources/adapty_flutter/Q.swift:1'), [
        'ios/adapty_flutter/Sources/adapty_flutter/Q.swift: no such file in this repository',
      ]);
      expect(problems('android/src/main/kotlin/F.kt:2-4'), ['android/src/main/kotlin/F.kt:2-4: the file has 3 lines']);
    });

    test('of this repository is checked against the files of this repository', () {
      const plugin = 'ios/adapty_flutter/Sources/adapty_flutter/SwiftAdaptyFlutterPlugin.swift';
      final refs = NativeRefs.of(ContractSource.load('.')).all;
      expect(sourceProblems('why', '$plugin:64-72', refs: refs), isEmpty);
      expect(sourceProblems('why', '$plugin:64-9999', refs: refs), [startsWith('$plugin:64-9999: the file has ')]);
    });

    test('outside the plugin is still a native file without its ref', () {
      expect(problems('ios/Runner/AppDelegate.swift:1'), [
        'ios/Runner/AppDelegate.swift:1: not under the ref of a native the contract is fixed to',
      ]);
    });
  });

  group('the refs a source names that are not fixed', () {
    test('are none when every ref is the one of its platform', () {
      expect(
        foreignRefs(
          'read: ios@release/9.9.9 Sources/A.swift:1; ignored: android@9.9.9: no emitter, android@9.9.9 b/C.kt:2',
          _refs,
        ),
        isEmpty,
      );
    });

    test('are an older ref, a ref of the other platform and a ref without a value, once each', () {
      expect(
        foreignRefs(
          'ios@release/9.9.8 A.swift:1 (also ios@release/9.9.8 B.swift), android@release/9.9.9 C.kt, ios@ D.swift',
          _refs,
        ),
        ['ios@release/9.9.8', 'android@release/9.9.9', 'ios@'],
      );
    });

    test('leave other words with an at sign alone', () {
      expect(foreignRefs('rn-sample@1.2.3 and user@example.com and macos@1', _refs), isEmpty);
    });
  });
}

/// The fields of the contract record [text] with the iOS ref and the version of the crossplatform library set to
/// values no record has.
Map<String, Object?> _withRefs(String text) {
  final fields = jsonDecode(text) as Map<String, Object?>;
  (fields['ios']! as Map<String, Object?>)['ref'] = '9.9.9';
  (fields['android']! as Map<String, Object?>)['crossplatform'] = '9.9.8';
  return fields;
}
