// What dart_apitool reads: a copy of the package in a folder named after the plugin. Flutter 3.50 copies a plugin
// whose folder has another name into build/ios/SourcePackages on every `pub get` that resolves the example, and the
// copy of the repository root then holds the copies of the earlier runs.
@TestOn('mac-os || linux')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/api/src/api_gate.dart';
import '../../tool/api/src/api_input.dart';

const _checkApi = 'tool/api/check_api.dart';

/// Creates a file at [path] under [root] with [content], and the folders above it.
void _file(String root, String path, [String content = '']) => File('$root/$path')
  ..createSync(recursive: true)
  ..writeAsStringSync(content.isEmpty ? path : content);

/// A package root with what dart_apitool reads and with what a checkout in use also has around it.
String _packageRoot(Directory temp) {
  final root = '${temp.path}/repo';
  _file(root, 'pubspec.yaml', 'name: adapty_flutter\n');
  _file(root, 'pubspec.lock');
  _file(root, 'analysis_options.yaml');
  _file(root, 'lib/adapty_flutter.dart');
  _file(root, 'lib/src/models/adapty_profile.dart');
  _file(root, 'ios/adapty_flutter/Package.swift');
  _file(root, 'ios/adapty_flutter/Sources/adapty_flutter/AdaptyFlutterPlugin.swift');
  _file(root, 'ios/adapty_flutter/.build/checkouts/AdaptySDK/Package.swift');
  _file(root, 'ios/x/.build/debug.yaml');
  _file(root, 'android/build.gradle');
  _file(root, 'android/src/main/kotlin/com/adapty/flutter/AdaptyFlutterPlugin.kt');
  _file(root, 'android/.gradle/8.0/checksums/checksums.lock');
  _file(root, 'android/.cxx/Debug/build.ninja');
  _file(root, 'android/build/intermediates/classes.jar');
  _file(root, 'android/.dart_tool/cache');
  _file(root, 'example/pubspec.yaml');
  _file(root, 'example/lib/main.dart');
  _file(root, 'integration_test_app/pubspec.yaml');
  _file(root, 'test/adapty_test.dart');
  _file(root, 'tool/api/check_api.dart');
  _file(root, 'contract/schema/adapty.yaml');
  _file(root, 'build/ios/SourcePackages/repo/pubspec.yaml');
  _file(root, '.dart_tool/package_config.json');
  _file(root, 'CHANGELOG.md');
  Link('$root/ios/adapty_flutter/Sources/adapty_flutter/Shared').createSync('../../../shared');
  return root;
}

/// The paths of the files, folders and links under [folder], relative to it, sorted.
List<String> _tree(String folder) => [
  for (final entity in Directory(folder).listSync(recursive: true, followLinks: false))
    '${entity.path.substring(folder.length + 1)}${entity is Directory ? '/' : ''}',
]..sort();

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('api_input_test_'));
  tearDown(() => temp.deleteSync(recursive: true));

  group('the copy of the package', () {
    test('is a new folder named after the plugin in the given folder', () {
      final root = _packageRoot(temp);
      final parent = Directory('${temp.path}/work')..createSync();

      final copy = copyApiInput(root, parent.path);

      expect(copy, '${parent.path}/adapty_flutter');
      expect(Directory(copy).existsSync(), isTrue);
    });

    test('holds the pubspec, the lock file, the analysis options and the lib, ios and android folders only', () {
      final root = _packageRoot(temp);

      final copy = copyApiInput(root, temp.path);

      expect(_tree(copy), [
        'analysis_options.yaml',
        'android/',
        'android/build.gradle',
        'android/src/',
        'android/src/main/',
        'android/src/main/kotlin/',
        'android/src/main/kotlin/com/',
        'android/src/main/kotlin/com/adapty/',
        'android/src/main/kotlin/com/adapty/flutter/',
        'android/src/main/kotlin/com/adapty/flutter/AdaptyFlutterPlugin.kt',
        'ios/',
        'ios/adapty_flutter/',
        'ios/adapty_flutter/Package.swift',
        'ios/adapty_flutter/Sources/',
        'ios/adapty_flutter/Sources/adapty_flutter/',
        'ios/adapty_flutter/Sources/adapty_flutter/AdaptyFlutterPlugin.swift',
        'ios/adapty_flutter/Sources/adapty_flutter/Shared',
        'ios/x/',
        'lib/',
        'lib/adapty_flutter.dart',
        'lib/src/',
        'lib/src/models/',
        'lib/src/models/adapty_profile.dart',
        'pubspec.lock',
        'pubspec.yaml',
      ]);
    });

    test('leaves out the build, Gradle, CMake, Swift Package Manager and Dart tool folders inside ios and android', () {
      final root = _packageRoot(temp);

      final copy = copyApiInput(root, temp.path);

      for (final skipped in [
        'ios/adapty_flutter/.build',
        'ios/x/.build',
        'android/.gradle',
        'android/.cxx',
        'android/build',
        'android/.dart_tool',
      ]) {
        expect(FileSystemEntity.typeSync('$copy/$skipped', followLinks: false), FileSystemEntityType.notFound);
      }
    });

    test('leaves out the example, the other apps, the tests, the tools, the contract and the root build folder', () {
      final root = _packageRoot(temp);

      final copy = copyApiInput(root, temp.path);

      for (final skipped in [
        'example',
        'integration_test_app',
        'test',
        'tool',
        'contract',
        'build',
        '.dart_tool',
        'CHANGELOG.md',
      ]) {
        expect(FileSystemEntity.typeSync('$copy/$skipped', followLinks: false), FileSystemEntityType.notFound);
      }
    });

    test('has the same bytes in every file and stands without the package', () {
      final root = _packageRoot(temp);
      File('$root/lib/adapty_flutter.dart').writeAsBytesSync([0, 1, 2, 255, 10, 13, 10]);
      const paths = [
        'pubspec.yaml',
        'pubspec.lock',
        'analysis_options.yaml',
        'lib/adapty_flutter.dart',
        'lib/src/models/adapty_profile.dart',
        'ios/adapty_flutter/Package.swift',
        'android/src/main/kotlin/com/adapty/flutter/AdaptyFlutterPlugin.kt',
      ];
      final bytes = {for (final path in paths) path: File('$root/$path').readAsBytesSync()};

      final copy = copyApiInput(root, temp.path);
      Directory(root).deleteSync(recursive: true);

      for (final path in paths) {
        expect(
          File('$copy/$path').existsSync() ? File('$copy/$path').readAsBytesSync() : null,
          bytes[path],
          reason: path,
        );
      }
    });

    test('keeps a link as a link to the same target', () {
      final root = _packageRoot(temp);

      final copy = copyApiInput(root, temp.path);
      Directory(root).deleteSync(recursive: true);

      final link = '$copy/ios/adapty_flutter/Sources/adapty_flutter/Shared';
      expect(FileSystemEntity.isLinkSync(link), isTrue);
      expect(Link(link).targetSync(), '../../../shared');
    });

    test('is made without a lock file or analysis options when the package has none', () {
      final root = _packageRoot(temp);
      File('$root/pubspec.lock').deleteSync();
      File('$root/analysis_options.yaml').deleteSync();

      final copy = copyApiInput(root, temp.path);
      Directory(root).deleteSync(recursive: true);

      expect(File('$copy/pubspec.yaml').existsSync(), isTrue);
      expect(File('$copy/pubspec.lock').existsSync(), isFalse);
      expect(File('$copy/analysis_options.yaml').existsSync(), isFalse);
    });

    test('is not made without a pubspec, and the error names it', () {
      final root = _packageRoot(temp);
      File('$root/pubspec.yaml').deleteSync();

      expect(
        () => copyApiInput(root, temp.path),
        throwsA(isA<FileSystemException>().having((error) => error.path, 'path', '$root/pubspec.yaml')),
      );
    });

    test('is not made without a lib folder, and the error names it', () {
      final root = _packageRoot(temp);
      Directory('$root/lib').deleteSync(recursive: true);

      expect(
        () => copyApiInput(root, temp.path),
        throwsA(isA<FileSystemException>().having((error) => error.path, 'path', '$root/lib')),
      );
    });

    test('is not made over an existing copy, and the error names it', () {
      final root = _packageRoot(temp);
      final copy = copyApiInput(root, temp.path);

      expect(
        () => copyApiInput(root, temp.path),
        throwsA(isA<FileSystemException>().having((error) => error.path, 'path', copy)),
      );
    });
  });

  group('the dart_apitool arguments', () {
    test('extract reads a copy of the package named after the plugin, not the package itself', () {
      final root = _packageRoot(temp);
      final work = Directory('${temp.path}/work')..createSync();

      final args = apitoolExtractArgs(root: root, temp: work.path, output: '${work.path}/api.json');

      expect(args, ['extract', '--input', '${work.path}/adapty_flutter', '--output', '${work.path}/api.json']);
      expect(args, isNot(contains(root)));
      expect(args, isNot(contains('.')));
      expect(File('${work.path}/adapty_flutter/pubspec.yaml').existsSync(), isTrue);
    });

    test('diff compares a copy of the package named after the plugin with the release', () {
      final root = _packageRoot(temp);
      final work = Directory('${temp.path}/work')..createSync();

      final args = apitoolDiffArgs(
        root: root,
        temp: work.path,
        old: 'pub://adapty_flutter/4.3.1',
        report: '${work.path}/diff.json',
      );

      expect(args, [
        'diff',
        '--old',
        'pub://adapty_flutter/4.3.1',
        '--new',
        '${work.path}/adapty_flutter',
        '--version-check-mode=none',
        '--report-format=json',
        '--report-file-path=${work.path}/diff.json',
      ]);
      expect(args, isNot(contains(root)));
      expect(args, isNot(contains('.')));
      expect(File('${work.path}/adapty_flutter/pubspec.yaml').existsSync(), isTrue);
    });

    test('diff after extract reads the copy extract made instead of copying the package again', () {
      final root = _packageRoot(temp);
      final work = Directory('${temp.path}/work')..createSync();
      apitoolExtractArgs(root: root, temp: work.path, output: '${work.path}/api.json');
      final marker = File('${work.path}/adapty_flutter/made_by_extract')..createSync(recursive: true);

      final args = apitoolDiffArgs(
        root: root,
        temp: work.path,
        old: 'pub://adapty_flutter/4.3.1',
        report: '${work.path}/diff.json',
      );

      expect(args[4], '${work.path}/adapty_flutter');
      expect(marker.existsSync(), isTrue);
    });

    test('the environment of a run puts the temporary folders of dart_apitool in the folder of the run', () {
      expect(apitoolEnvironment(temp.path), {'TMPDIR': temp.path});
    });
  });

  group('check_api.dart', () {
    /// The code of check_api.dart without comment lines.
    String code() => [
      for (final line in File(_checkApi).readAsLinesSync())
        if (!line.trimLeft().startsWith('//')) line,
    ].join('\n');

    test('builds the extract and diff arguments with the functions that copy the package', () {
      expect(code(), matches(RegExp(r'_apitool\(\s*apitoolExtractArgs\(')));
      expect(code(), matches(RegExp(r'_apitool\(\s*apitoolDiffArgs\(')));
    });

    test('runs extract and diff with their temporary folders in the folder it deletes at the end', () {
      expect(code(), matches(RegExp(r'_apitool\(\s*apitoolExtractArgs\([^;]*environment: apitoolEnvironment\(temp\)')));
      expect(code(), matches(RegExp(r'_apitool\(\s*apitoolDiffArgs\([^;]*environment: apitoolEnvironment\(temp\)')));
    });

    test('runs extract and diff, which read pub.dev, again while pub cannot reach it', () {
      expect(code(), matches(RegExp(r'_apitool\(\s*apitoolExtractArgs\([^;]*readsPub: true')));
      expect(code(), matches(RegExp(r'_apitool\(\s*apitoolDiffArgs\([^;]*readsPub: true')));
      expect(code(), matches(RegExp(r'runApitool\(args, environment: environment, readsPub: readsPub\)')));
    });

    test('tells the gate that a failed diff could not reach pub.dev', () {
      expect(
        code(),
        matches(
          RegExp(r'diffNeedsNetwork = apitoolNeedsNetwork\(\s*.\$\{result\.stdout\}\\n\$\{result\.stderr\}.\s*\);'),
        ),
      );
      expect(code(), matches(RegExp(r'evaluateApiGate\([^;]*diffNeedsNetwork: diffNeedsNetwork,')));
    });

    test('passes dart_apitool no literal list of arguments other than the version query', () {
      expect(RegExp(r"_apitool\(\s*\[(?!\s*'--version'\s*\])").allMatches(code()).map((m) => m[0]), isEmpty);
    });

    /// The code from the first [start] to the first `return 1;` after it.
    String block(String start) {
      final text = code();
      final from = text.indexOf(start);
      expect(from, isNot(-1), reason: start);
      return text.substring(from, text.indexOf('return 1;', from));
    }

    test('prints the tail of the dart_apitool output when extract fails', () {
      expect(block('if (extract.exitCode != 0) {'), contains('_printTail(extract);'));
    });

    test('prints the tail of the dart_apitool output after the gate failures when diff fails', () {
      expect(code(), contains('failedDiff = result;'));
      expect(block('result.failures.forEach(stdout.writeln);'), contains('_printTail(failedDiff);'));
    });
  });
}
