// What ci.yml lets its jobs do. Without a permissions block the token of every job gets the default permissions of
// the repository settings, which may include writing to it; and a third-party action named by a tag runs whatever
// commit the tag is moved to. The jobs that check the public API and run the JVM tests of the Android plugin name
// their third-party actions by commit, as the native probe workflow does.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'workflow_actions.dart';

const _workflowPath = '.github/workflows/ci.yml';

/// The jobs whose third-party actions are named by commit.
const _fixedJobs = ['api', 'android-unit'];

/// The lines of [job] in the workflow [text]: from its key to the key of the next job, or to the end of the file.
List<String> _jobLines(String text, String job) {
  final lines = text.split('\n');
  final start = lines.indexOf('  $job:');
  if (start < 0) return [];
  final end = lines.indexWhere((line) => RegExp(r'^ {0,2}[^\s#]').hasMatch(line), start + 1);
  return lines.sublist(start, end < 0 ? lines.length : end);
}

/// What is wrong with the permissions of the workflow [text]: the workflow has to give its token read access to the
/// contents only, and no job may give its own token more.
List<String> _permissionProblems(String text) {
  final workflow = loadYaml(text) as YamlMap;
  final permissions = workflow['permissions'];
  final problems = <String>[
    if (permissions is! YamlMap || permissions.length != 1 || permissions['contents'] != 'read')
      'the workflow permissions are $permissions, not {contents: read}',
  ];
  for (final MapEntry(key: name, value: job) in (workflow['jobs'] as YamlMap).entries) {
    final own = (job as YamlMap)['permissions'];
    if (own == null) continue;
    final narrower =
        own is YamlMap &&
        own.entries.every((e) => e.value == 'none' || (permissions is YamlMap && permissions[e.key] == e.value));
    if (!narrower) problems.add('$name: the job permissions $own give more than the workflow');
  }
  return problems;
}

void main() {
  final text = File(_workflowPath).readAsStringSync();

  test('the jobs that check the public API and run the Android unit tests name third-party actions by commit', () {
    for (final job in _fixedJobs) {
      final lines = _jobLines(text, job);
      expect(lines, isNotEmpty, reason: 'no job $job');
      final thirdParty = thirdPartyUses(lines);
      expect(thirdParty, isNotEmpty, reason: '$job: no third-party action');
      for (final line in thirdParty) {
        expect(line, matches(fixedToCommit), reason: job);
      }
    }
  });

  test('ci.yml gives the token of every job read access to the contents only', () {
    expect(_permissionProblems(text), isEmpty);
  });

  group('the lines of a job', () {
    const workflow = '''
on: push
jobs:
  api:
    steps:
      - uses: actions/checkout@v5
      # a comment between the steps
      - uses: subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2 # v2
  # a comment before the next job
  android-unit:
    steps:
      - uses: subosito/flutter-action@v2
''';

    test('end where the next job starts, so that its actions do not count', () {
      final api = thirdPartyUses(_jobLines(workflow, 'api'));
      expect(api, ['- uses: subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2 # v2']);
      expect(api.single, matches(fixedToCommit));
      expect(thirdPartyUses(_jobLines(workflow, 'android-unit')).single, isNot(matches(fixedToCommit)));
    });

    test('are empty for a job the workflow does not have', () {
      expect(_jobLines(workflow, 'analyze-test'), isEmpty);
    });

    test('name an action by commit only with the full commit and its tag next to it', () {
      expect('uses: a/b@1a449444c387b1966244ae4d4f8c696479add0b2 # v2.23.0', matches(fixedToCommit));
      expect('uses: a/b@1a449444c387b1966244ae4d4f8c696479add0b2', isNot(matches(fixedToCommit)));
      expect('uses: a/b@1a449444 # v2', isNot(matches(fixedToCommit)));
      expect('uses: a/b@v2', isNot(matches(fixedToCommit)));
    });
  });

  group('the permissions of a workflow', () {
    String workflow({String top = 'permissions:\n  contents: read\n', String job = ''}) =>
        '${top}jobs:\n  api:\n$job    steps: []\n  other:\n    steps: []\n';

    test('are right with read access to the contents and jobs that keep it or give less', () {
      expect(_permissionProblems(workflow()), isEmpty);
      expect(_permissionProblems(workflow(job: '    permissions:\n      contents: read\n')), isEmpty);
      expect(_permissionProblems(workflow(job: '    permissions:\n      contents: none\n')), isEmpty);
    });

    test('are wrong when the workflow sets none, more or another access', () {
      expect(_permissionProblems(workflow(top: '')), ['the workflow permissions are null, not {contents: read}']);
      expect(_permissionProblems(workflow(top: 'permissions: read-all\n')), hasLength(1));
      expect(_permissionProblems(workflow(top: 'permissions:\n  contents: write\n')), hasLength(1));
      expect(
        _permissionProblems(workflow(top: 'permissions:\n  contents: read\n  pull-requests: read\n')),
        hasLength(1),
      );
    });

    test('are wrong when a job gives its token more than the workflow', () {
      expect(_permissionProblems(workflow(job: '    permissions:\n      contents: write\n')), [
        'api: the job permissions {contents: write} give more than the workflow',
      ]);
      expect(_permissionProblems(workflow(job: '    permissions:\n      actions: write\n')), hasLength(1));
      expect(_permissionProblems(workflow(job: '    permissions: write-all\n')), hasLength(1));
    });
  });
}
