import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Lays out a minimal package tree in [root] that the kids generator can run on: the real generator files of this
/// package, a pubspec, the iOS package folder, one library file, and the given extra files (path to content).
void _layOutPackage(Directory root, Map<String, String> extraFiles) {
  void write(String path, String content) => File('${root.path}/$path')
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  for (final name in ['generate.sh', 'Package.swift', 'pubspec.patch.dart', '.pubignore']) {
    write('tool/kids/$name', File('tool/kids/$name').readAsStringSync());
  }
  write('pubspec.yaml', 'name: adapty_flutter\ndescription: the full package\nversion: 1.0.0\n');
  write('ios/adapty_flutter/Package.swift', '// the iOS package\n');
  write('lib/adapty_flutter.dart', '// the library\n');
  extraFiles.forEach(write);
}

/// Every file under [folder], relative to [root].
List<String> _filesUnder(String root, String folder) => [
  for (final entity in Directory('$root/$folder').listSync(recursive: true))
    if (entity is File) entity.path.substring(root.length + 1),
];

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('kids_excludes_'));
  tearDown(() => temp.deleteSync(recursive: true));

  test('the generated kids package keeps only the schema of the contract and leaves out the integration test app', () {
    final source = Directory('${temp.path}/source')..createSync();
    final out = '${temp.path}/out';
    _layOutPackage(source, {
      'contract/cross_platform.yaml': 'channel: adapty\nmethods: {}\n',
      'contract/other.yaml': 'cases: []\n',
      'integration_test_app/marker.txt': 'present\n',
    });

    final result = Process.runSync('bash', ['${source.path}/tool/kids/generate.sh', out]);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(File('$out/lib/adapty_flutter.dart').existsSync(), isTrue, reason: 'the library is copied');
    expect(File('$out/pubspec.yaml').readAsStringSync(), contains('name: adapty_flutter_kids'));
    final schema = File('$out/contract/cross_platform.yaml');
    expect(schema.existsSync(), isTrue, reason: 'the schema of the method channel is copied');
    expect(schema.readAsBytesSync(), File('${source.path}/contract/cross_platform.yaml').readAsBytesSync());
    expect(_filesUnder(out, 'contract'), [
      'contract/cross_platform.yaml',
    ], reason: 'the rest of contract/ serves the tests');
    expect(
      Directory('$out/integration_test_app').existsSync(),
      isFalse,
      reason: 'the integration test app is for tests only',
    );
  });
}
