// The api job of ci.yml installs dart_apitool from pub.dev before it checks the public API. pub tries a request again
// for some seconds by itself; a minute of trouble with pub.dev or with the network of the runner would still turn the
// job red with no change to the API, so the step runs the install again before it gives up.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const _workflowPath = '.github/workflows/ci.yml';

/// The script of the step of the api job that installs dart_apitool.
String _installScript() {
  final jobs = (loadYaml(File(_workflowPath).readAsStringSync()) as YamlMap)['jobs'] as YamlMap;
  final steps = (jobs['api'] as YamlMap)['steps'] as YamlList;
  return steps.cast<YamlMap>().singleWhere((step) => step['name'] == 'Install dart_apitool')['run'] as String;
}

/// The version of dart_apitool that tool/api/check_api.dart requires.
String _requiredVersion() =>
    RegExp(r"_apitoolVersion = '([^']+)'").firstMatch(File('tool/api/check_api.dart').readAsStringSync())![1]!;

/// What a run of the install step did with a `dart` that fails until its [succeedAt]th run (never with 0): its exit
/// code, what it printed, the arguments of each run of `dart`, and the pauses it took.
Future<({int exitCode, String output, List<String> runs, List<String> pauses})> _install(int succeedAt) async {
  final dir = Directory.systemTemp.createTempSync('ci_api_install_');
  addTearDown(() => dir.deleteSync(recursive: true));
  for (final (name, body) in [
    (
      'dart',
      'echo "\$*" >> "\$FAKE_DIR/runs"\n[ "\$SUCCEED_AT" != 0 ] && [ \$(wc -l < "\$FAKE_DIR/runs") -ge "\$SUCCEED_AT" ]',
    ),
    ('sleep', 'echo "\$*" >> "\$FAKE_DIR/pauses"'),
  ]) {
    final file = File('${dir.path}/$name')..writeAsStringSync('#!/bin/bash\n$body\n');
    Process.runSync('chmod', ['+x', file.path]);
  }
  final result = await Process.run(
    'bash',
    ['-e', '-c', _installScript()],
    environment: {
      'PATH': '${dir.path}:${Platform.environment['PATH']}',
      'FAKE_DIR': dir.path,
      'SUCCEED_AT': '$succeedAt',
    },
  );
  List<String> lines(String name) {
    final file = File('${dir.path}/$name');
    return file.existsSync() ? file.readAsLinesSync() : const [];
  }

  return (exitCode: result.exitCode, output: '${result.stdout}', runs: lines('runs'), pauses: lines('pauses'));
}

void main() {
  test('the api job installs the version of dart_apitool the check needs, once when pub.dev answers', () async {
    final install = await _install(1);

    expect(install.exitCode, 0);
    expect(install.runs, ['pub global activate dart_apitool ${_requiredVersion()}']);
    expect(install.pauses, isEmpty);
  });

  test('the api job installs dart_apitool again after a failed install, and succeeds on the third run', () async {
    final install = await _install(3);

    expect(install.exitCode, 0);
    expect(install.runs, hasLength(3));
    expect(install.pauses, hasLength(2));
  });

  test('the api job gives up after three failed installs, and says it was pub.dev, not the API', () async {
    final install = await _install(0);

    expect(install.exitCode, isNot(0));
    expect(install.runs, hasLength(3));
    expect(install.pauses, hasLength(2));
    expect(install.output, contains('::error::could not install dart_apitool from pub.dev'));
  });
}
