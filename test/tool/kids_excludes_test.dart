import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Lays out a minimal package tree in [root] that the kids generator can run on: the real generator files of this
/// package, a pubspec, the iOS package folder, one library file, and the given extra folders, each with one file.
void _layOutPackage(Directory root, List<String> extraFolders) {
  void write(String path, String content) => File('${root.path}/$path')
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  for (final name in ['generate.sh', 'Package.swift', 'pubspec.patch.dart', '.pubignore']) {
    write('tool/kids/$name', File('tool/kids/$name').readAsStringSync());
  }
  write('pubspec.yaml', 'name: adapty_flutter\ndescription: the full package\nversion: 1.0.0\n');
  write('ios/adapty_flutter/Package.swift', '// the iOS package\n');
  write('lib/adapty_flutter.dart', '// the library\n');
  for (final folder in extraFolders) {
    write('$folder/marker.txt', 'present\n');
  }
}

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('kids_excludes_'));
  tearDown(() => temp.deleteSync(recursive: true));

  test('the generated kids package leaves out the contract and the integration test app', () {
    final source = Directory('${temp.path}/source')..createSync();
    final out = '${temp.path}/out';
    _layOutPackage(source, ['contract', 'integration_test_app']);

    final result = Process.runSync('bash', ['${source.path}/tool/kids/generate.sh', out]);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(File('$out/lib/adapty_flutter.dart').existsSync(), isTrue, reason: 'the library is copied');
    expect(File('$out/pubspec.yaml').readAsStringSync(), contains('name: adapty_flutter_kids'));
    expect(Directory('$out/contract').existsSync(), isFalse, reason: 'the contract corpus is for tests only');
    expect(
      Directory('$out/integration_test_app').existsSync(),
      isFalse,
      reason: 'the integration test app is for tests only',
    );
  });
}
