// The refs of the natives a contract record is fixed to, and the refs a source names that are not those.
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
      ..writeAsStringSync(
        File(ContractSource.recordPath)
            .readAsStringSync()
            .replaceFirst('"ref": "release/4.4.1"', '"ref": "4.4.1"')
            .replaceFirst('"crossplatform": "4.4.0"', '"crossplatform": "4.4.3"'),
      );

    final refs = NativeRefs.of(ContractSource.load(root.path));

    expect((refs.ios, refs.android), ('ios@4.4.1', 'android@4.4.3'));
    expect(refs.of(ContractPlatform.ios), 'ios@4.4.1');
    expect(refs.of(ContractPlatform.android), 'android@4.4.3');
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
