// What the published package leaves out (.pubignore). pub reads .pubignore instead of .gitignore in the same folder,
// so the root .pubignore repeats every rule of the root .gitignore, and adds rules for the tests of the contract and of
// the native probe and for what only they read. The schema under contract/ stays in the package.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The rules of a .gitignore or .pubignore file, read as pub and git read them.
class _IgnoreRules {
  _IgnoreRules(String text) : _rules = [for (final line in text.split('\n')) ?_Rule.parse(line)];

  final List<_Rule> _rules;

  /// Whether the file or folder at [path] (relative to the root, with `/`) is left out: a path is left out when one
  /// of its folders is, and otherwise when the last rule that matches it does not start with `!`.
  bool ignores(String path, {bool isFolder = false}) {
    final segments = path.split('/');
    for (var length = 1; length <= segments.length; length++) {
      final folder = length < segments.length || isFolder;
      final prefix = segments.take(length).join('/');
      final matching = _rules.where((rule) => (folder || !rule.foldersOnly) && rule.pattern.hasMatch(prefix));
      if (matching.isNotEmpty && !matching.last.negated) return true;
    }
    return false;
  }
}

class _Rule {
  _Rule(this.negated, this.foldersOnly, this.pattern);

  final bool negated;
  final bool foldersOnly;
  final RegExp pattern;

  static _Rule? parse(String line) {
    var rule = line.trimRight();
    if (rule.isEmpty || rule.startsWith('#')) return null;
    final negated = rule.startsWith('!');
    if (negated) rule = rule.substring(1);
    final foldersOnly = rule.endsWith('/');
    if (foldersOnly) rule = rule.substring(0, rule.length - 1);
    final anchored = rule.contains('/');
    if (rule.startsWith('/')) rule = rule.substring(1);
    final body = StringBuffer();
    for (var i = 0; i < rule.length; i++) {
      if (rule.startsWith('**/', i)) {
        body.write('(?:.*/)?');
        i += 2;
      } else if (rule.startsWith('/**', i) && i + 3 == rule.length) {
        body.write('/.*');
        i += 2;
      } else if (rule[i] == '*') {
        body.write('[^/]*');
      } else if (rule[i] == '?') {
        body.write('[^/]');
      } else {
        body.write(RegExp.escape(rule[i]));
      }
    }
    return _Rule(negated, foldersOnly, RegExp('^${anchored ? '' : '(?:.*/)?'}$body\$'));
  }
}

/// The rules of [path] that are neither blank nor comments, as written.
List<String> _rulesOf(String path) => [
  for (final line in File(path).readAsLinesSync())
    if (line.trim().isNotEmpty && !line.trimLeft().startsWith('#')) line.trimRight(),
];

/// Every file under [folder], relative to the root.
List<String> _filesUnder(String folder) => [
  for (final entity in Directory(folder).listSync(recursive: true))
    if (entity is File) entity.path,
];

void main() {
  final gitignore = _rulesOf('.gitignore');
  final pubignore = _rulesOf('.pubignore');
  final package = _IgnoreRules(File('.pubignore').readAsStringSync());

  test('every rule of .gitignore is in .pubignore, which pub reads instead', () {
    expect(gitignore, isNotEmpty);
    expect(gitignore.where((rule) => !pubignore.contains(rule)), isEmpty);
  });

  test('every other rule of .pubignore starts at the root and names a path that exists', () {
    final own = pubignore.where((rule) => !gitignore.contains(rule)).toList();
    expect(own, isNotEmpty);
    for (final rule in own) {
      expect(rule, matches(RegExp(r'^!?/')), reason: 'a rule without / at the start matches in every folder');
      final path = rule
          .replaceFirst(RegExp(r'^!?/'), '')
          .split(RegExp(r'[*?\[]'))
          .first
          .replaceFirst(RegExp(r'/$'), '');
      expect(FileSystemEntity.typeSync(path), isNot(FileSystemEntityType.notFound), reason: rule);
    }
  });

  test('the package keeps the schema of the contract, the library and the native code', () {
    for (final path in [
      'contract/cross_platform.yaml',
      'lib/adapty_flutter.dart',
      'pubspec.yaml',
      'README.md',
      'CHANGELOG.md',
      'LICENSE',
      'ios/adapty_flutter/Package.swift',
      'android/build.gradle',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: path);
      expect(package.ignores(path), isFalse, reason: path);
    }
  });

  test('the package leaves out the tests of the contract and of the native probe and what only they read', () {
    for (final folder in [
      'integration_test_app',
      'tool/contract',
      'tool/l2a',
      'test/contract',
      'test/support/contract',
    ]) {
      expect(package.ignores(folder, isFolder: true), isTrue, reason: folder);
    }
    final contract = _filesUnder('contract').where((path) => path != 'contract/cross_platform.yaml');
    expect(contract, isNotEmpty);
    expect(contract.where((path) => !package.ignores(path)), isEmpty);
  });

  test('every test the package keeps imports only files the package keeps', () {
    final kept = _filesUnder('test').where((path) => path.endsWith('.dart') && !package.ignores(path)).toList();
    expect(kept, isNotEmpty);
    final directive = RegExp(r'''^(?:import|export|part)\s+'([^']+)'.*;''', multiLine: true);
    final missing = [
      for (final path in kept)
        for (final match in directive.allMatches(File(path).readAsStringSync()))
          if (!match[1]!.contains(':'))
            if (Uri.parse(path).resolve(match[1]!).path case final target when package.ignores(target))
              '$path: $target',
    ];
    expect(missing, isEmpty);
  });

  group('reading the rules', () {
    test('a rule with a / before its end matches from the root only, one without it in every folder', () {
      final rules = _IgnoreRules('/build/\nexamples/all_plugins/pubspec.yaml\n*.iml\n');
      expect(rules.ignores('build/a.dart'), isTrue);
      expect(rules.ignores('example/build/a.dart'), isFalse);
      expect(rules.ignores('examples/all_plugins/pubspec.yaml'), isTrue);
      expect(rules.ignores('x/examples/all_plugins/pubspec.yaml'), isFalse);
      expect(rules.ignores('android/a.iml'), isTrue);
    });

    test('a rule that ends with / matches folders only, and **/ matches any number of folders', () {
      final rules = _IgnoreRules('build/\n**/Flutter/ephemeral/\n');
      expect(rules.ignores('build'), isFalse);
      expect(rules.ignores('a/build/b'), isTrue);
      expect(rules.ignores('Flutter/ephemeral/x'), isTrue);
      expect(rules.ignores('ios/Flutter/ephemeral/x'), isTrue);
    });

    test('a rule with ! takes a file back, but not from a folder that is left out', () {
      expect(_IgnoreRules('/contract/*\n!/contract/schema.yaml\n').ignores('contract/schema.yaml'), isFalse);
      expect(_IgnoreRules('/contract/*\n!/contract/schema.yaml\n').ignores('contract/other.yaml'), isTrue);
      expect(_IgnoreRules('/contract/\n!/contract/schema.yaml\n').ignores('contract/schema.yaml'), isTrue);
    });
  });
}
