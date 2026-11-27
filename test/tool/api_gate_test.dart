import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/api/src/api_gate.dart';

// A `dart_apitool diff` report with one renamed parameter and one added method, as the tool writes it.
const _renamedParameterReport = r'''
{
  "reportName": "API Changes Report",
  "apiToolInfo": {
    "toolName": "dart_apitool",
    "toolVersion": "0.23.2",
    "toolAuthor": "BMW Tech",
    "generatedAt": "2026-11-19 08:10:12.412391",
    "oldRef": "pub://adapty_flutter/4.3.1",
    "newRef": "."
  },
  "report": {
    "breakingChanges": {
      "label": "BREAKING CHANGES",
      "children": [
        {
          "label": "Class Adapty",
          "children": [
            {
              "label": "Method getFlow",
              "children": [
                {
                  "changeDescription": "Name of parameter \"placementId\" changed. placementId -> placement",
                  "changeCode": "CE03",
                  "isBreaking": true,
                  "type": "major"
                }
              ]
            }
          ]
        }
      ]
    },
    "nonBreakingChanges": {
      "label": "Non-Breaking changes",
      "children": [
        {
          "label": "Class Adapty",
          "children": [
            {
              "changeDescription": "Method \"probe\" added",
              "changeCode": "CE11",
              "isBreaking": false,
              "type": "minor"
            }
          ]
        }
      ]
    }
  }
}
''';

// A report with one added method only: the tool leaves out the section that has no changes.
const _addedMethodReport = r'''
{
  "reportName": "API Changes Report",
  "apiToolInfo": {
    "toolName": "dart_apitool",
    "toolVersion": "0.23.2",
    "toolAuthor": "BMW Tech",
    "generatedAt": "2026-11-19 08:05:42.169316",
    "oldRef": "pub://adapty_flutter/4.3.1",
    "newRef": "."
  },
  "report": {
    "nonBreakingChanges": {
      "label": "Non-Breaking changes",
      "children": [
        {
          "label": "Class AdaptyUI",
          "children": [
            {
              "changeDescription": "Method \"sendAppMessage\" added",
              "changeCode": "CE11",
              "isBreaking": false,
              "type": "minor"
            }
          ]
        }
      ]
    }
  }
}
''';

// The report of a tree whose API equals the release it is compared with.
const _noChangesReport = r'''
{
  "reportName": "API Changes Report",
  "apiToolInfo": {
    "toolName": "dart_apitool",
    "toolVersion": "0.23.2",
    "toolAuthor": "BMW Tech",
    "generatedAt": "2026-11-19 08:34:10.306147",
    "oldRef": "pub://adapty_flutter/4.3.1",
    "newRef": "pub://adapty_flutter/4.3.1"
  },
  "report": {
    "noChangesDetected": true
  }
}
''';

const _changelogWithoutBreakingLine = '''
# 4.4.0-dev.1

### ✨ Added

- `AdaptyUI().sendAppMessage()` sends a message to the script of a flow.

# 4.3.1

### 🐛 Fixed

- A fix.

# 4.3.0

### ⚠️ Breaking

- A breaking change of an earlier release.
''';

const _changelogWithBreakingLine = '''
# 4.4.0-dev.1

### ⚠️ Breaking

- Fallback files have a new format.

### ✨ Added

- `AdaptyUI().sendAppMessage()` sends a message to the script of a flow.

# 4.3.1

### 🐛 Fixed

- A fix.
''';

ApiDiffReport _diff(String report) => ApiDiffReport.fromApitoolJson(jsonDecode(report) as Map<String, Object?>);

void main() {
  test('a changed snapshot fails with the update command', () {
    final result = evaluateApiGate(
      const ApiGateInput(
        pubspecVersion: '4.4.0-dev.1',
        lastRelease: '4.3.1',
        releaseLine: false,
        snapshotMatches: false,
      ),
    );

    expect(result.ok, isFalse);
    expect(result.failures.single, contains('check_api.dart --update'));
  });

  test('any API change while pubspec still equals the last release fails', () {
    final result = evaluateApiGate(
      ApiGateInput(
        pubspecVersion: '4.3.1',
        lastRelease: '4.3.1',
        releaseLine: false,
        snapshotMatches: true,
        diff: _diff(_addedMethodReport),
        changelogSectionForVersion: changelogSection(_changelogWithoutBreakingLine, '4.3.1'),
      ),
    );

    expect(result.failures.single, contains('start the development version'));
  });

  test('an unchanged API passes while pubspec still equals the last release', () {
    final result = evaluateApiGate(
      ApiGateInput(
        pubspecVersion: '4.4.0',
        lastRelease: '4.4.0',
        releaseLine: false,
        snapshotMatches: true,
        diff: _diff(_noChangesReport),
        changelogSectionForVersion: '### ✨ Added\n\n- Something new.\n',
      ),
    );

    expect(result.failures, isEmpty);
  });

  test('a breaking change in a minor without a Breaking line fails', () {
    final result = evaluateApiGate(
      ApiGateInput(
        pubspecVersion: '4.4.0-dev.1',
        lastRelease: '4.3.1',
        releaseLine: false,
        snapshotMatches: true,
        diff: _diff(_renamedParameterReport),
        changelogSectionForVersion: changelogSection(_changelogWithoutBreakingLine, '4.4.0-dev.1'),
      ),
    );

    expect(result.failures.single, contains("'### ⚠️ Breaking'"));
    expect(
      result.failures.single,
      contains(
        'CHANGELOG.md: Class Adapty > Method getFlow: Name of parameter "placementId" changed. placementId -> placement',
      ),
    );
    expect(result.failures.single, isNot(contains('probe')));

    final withoutSection = evaluateApiGate(
      ApiGateInput(
        pubspecVersion: '4.4.0-dev.1',
        lastRelease: '4.3.1',
        releaseLine: false,
        snapshotMatches: true,
        diff: _diff(_renamedParameterReport),
        changelogSectionForVersion: null,
      ),
    );

    expect(withoutSection.failures.single, contains("'### ⚠️ Breaking'"));
  });

  test('a breaking change with a Breaking line passes', () {
    final result = evaluateApiGate(
      ApiGateInput(
        pubspecVersion: '4.4.0-dev.1',
        lastRelease: '4.3.1',
        releaseLine: false,
        snapshotMatches: true,
        diff: _diff(_renamedParameterReport),
        changelogSectionForVersion: changelogSection(_changelogWithBreakingLine, '4.4.0-dev.1'),
      ),
    );

    expect(result.failures, isEmpty);
    expect(result.ok, isTrue);
  });

  test('a breaking change with a major bump passes', () {
    final result = evaluateApiGate(
      ApiGateInput(
        pubspecVersion: '5.0.0-dev.1',
        lastRelease: '4.3.1',
        releaseLine: false,
        snapshotMatches: true,
        diff: _diff(_renamedParameterReport),
        changelogSectionForVersion: '### ✨ Added\n\n- Something new.\n',
      ),
    );

    expect(result.failures, isEmpty);
  });

  test('a comparison with the last release that cannot run fails with its reason, without guessing the cause', () {
    final result = evaluateApiGate(
      const ApiGateInput(
        pubspecVersion: '4.4.0',
        lastRelease: '4.4.0',
        releaseLine: false,
        snapshotMatches: true,
        diff: null,
        diffError: 'package not found',
      ),
    );

    expect(result.failures.single, contains('cannot compare with adapty_flutter 4.4.0: package not found'));
    expect(result.failures.single, isNot(contains('pub.dev')));
  });

  test('dev line: the last release is the newest plain heading not above the pubspec version', () {
    const devChangelog = '''
# 4.4.0

- Something new, released.

# 4.4.0-dev.1

### ✨ Added

- Something new.

# 4.3.1

- A fix.

# 4.3.0

- A feature.
''';
    const releasedChangelog = '''
# 4.4.0

- Something new.

# 4.3.1

- A fix.
''';

    expect(lastReleaseFromChangelog(devChangelog, pubspecVersion: '4.4.0-dev.1', releaseLine: false), '4.3.1');
    expect(lastReleaseFromChangelog(releasedChangelog, pubspecVersion: '4.4.0', releaseLine: false), '4.4.0');
  });

  test('release line: the last release is the newest plain heading below the pubspec version', () {
    const releasedChangelog = '''
# 4.4.0

- Something new.

# 4.3.1

- A fix.

# 4.3.0

- A feature.
''';

    expect(lastReleaseFromChangelog(releasedChangelog, pubspecVersion: '4.4.0', releaseLine: true), '4.3.1');
  });

  test('release line on a hotfix: the last release is the previous patch of the same minor version', () {
    const hotfixChangelog = '''
# 4.3.1

- A fix.

# 4.3.0

- A feature.

# 4.2.2

- An older fix.
''';

    expect(lastReleaseFromChangelog(hotfixChangelog, pubspecVersion: '4.3.1', releaseLine: true), '4.3.0');
  });

  test('normalization drops paths and versions and sorts keys', () {
    const extracted = '''
{"version":3,"packageApi":{"packageName":"adapty_flutter","packageVersion":"4.4.0-dev.1","packagePath":"/var/folders/j_/T/9UjXmM","interfaceDeclarations":[{"name":"Adapty","isDeprecated":false,"executableDeclarations":[{"returnTypeName":"Future<AdaptyFlow>","name":"getFlow","parameters":[{"name":"placementId","isNamed":true,"typeName":"String","relativePath":"lib/src/adapty.dart"},{"name":"locale","isNamed":true,"typeName":"String?","relativePath":"lib/src/adapty.dart"}],"type":"method","relativePath":"lib/src/adapty.dart"}],"relativePath":"lib/src/adapty.dart"}],"sdkType":"flutter","minSdkVersion":"3.8.0","packageDependencies":[{"packageName":"meta","packageVersion":"^1.3.0"}]},"missingEntryPoints":[]}''';

    expect(normalizeApiSnapshot(extracted), '''
{
  "missingEntryPoints": [],
  "packageApi": {
    "interfaceDeclarations": [
      {
        "executableDeclarations": [
          {
            "name": "getFlow",
            "parameters": [
              {
                "isNamed": true,
                "name": "placementId",
                "typeName": "String"
              },
              {
                "isNamed": true,
                "name": "locale",
                "typeName": "String?"
              }
            ],
            "returnTypeName": "Future<AdaptyFlow>",
            "type": "method"
          }
        ],
        "isDeprecated": false,
        "name": "Adapty"
      }
    ],
    "minSdkVersion": "3.8.0",
    "packageDependencies": [
      {
        "packageName": "meta",
        "packageVersion": "^1.3.0"
      }
    ],
    "packageName": "adapty_flutter",
    "sdkType": "flutter"
  }
}
''');
  });

  test('the tool counts as installed when pub prints its rebuild before the version', () {
    const output = '''
Resolving dependencies...
Downloading packages...
  _fe_analyzer_shared 96.0.0 (111.0.0 available)
  analyzer 10.2.0 (14.7.0 available)
  package_config 2.2.0 (3.0.0 available)
  petitparser 7.0.2 (7.1.0 available)
  plist_parser 0.2.7 (0.3.0 available)
  pubspec_manager 1.0.3 (4.1.1 available)
  xml 6.6.1 (7.1.0 available)
No dependencies would change in `/home/runner/.pub-cache/global_packages/dart_apitool`.
7 packages have newer versions incompatible with dependency constraints.
Try `dart pub outdated` for more information.
0.23.2
''';

    expect(apitoolVersionMatches(output, '0.23.2'), isTrue);
  });

  test('another version of the tool does not count as installed', () {
    expect(apitoolVersionMatches('0.24.0\n', '0.23.2'), isFalse);
    expect(apitoolVersionMatches('0.23.20\n', '0.23.2'), isFalse);
    expect(apitoolVersionMatches('', '0.23.2'), isFalse);
  });

  test('an extract that pub could not resolve without the network needs network access', () {
    // What `dart_apitool extract` prints, stdout then stderr, on a checkout without pubspec.lock and without network.
    const output = '''
Preparing .
Copying sources from .
Preparing package dependencies for local package .
Resolving dependencies...
Got socket error trying to find package meta at https://pub.dev.
Failed to update packages.

Error: Exception: Got socket error trying to find package meta at https://pub.dev.
Failed to update packages.
''';

    expect(apitoolNeedsNetwork(output), isTrue);
  });

  test('an extract that pub could not resolve without the network despite a lock file needs network access', () {
    // What `dart_apitool extract` prints, stdout then stderr, with pubspec.lock in place and without network: pub
    // still fetches security advisories from pub.dev.
    const output = '''
Preparing .
Copying sources from .
Preparing package dependencies for local package .
Resolving dependencies...
Downloading packages...
  clock 1.1.2 (1.1.3 available)
  matcher 0.12.19 (0.12.20 available)
  material_color_utilities 0.13.0 (0.13.1 available)
  meta 1.17.0 (1.19.0 available)
  stack_trace 1.12.1 (1.12.2 available)
  test_api 0.7.10 (0.7.15 available)
  vector_math 2.2.0 (2.4.4 available)
Got dependencies!
7 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Resolving dependencies in `./example`...
Downloading packages...
ClientException with SocketException: Connection refused (OS Error: Connection refused, errno = 61), address = 127.0.0.1, port = 64252, uri=https://pub.dev/api/packages/shared_preferences_android/advisories
Failed to update packages.

Error: Exception: ClientException with SocketException: Connection refused (OS Error: Connection refused, errno = 61), address = 127.0.0.1, port = 64252, uri=https://pub.dev/api/packages/shared_preferences_android/advisories
Failed to update packages.
''';

    expect(apitoolNeedsNetwork(output), isTrue);
  });

  test('an extract that failed on a broken pubspec does not ask for network access', () {
    const output = '''
Preparing .
Copying sources from .
Preparing package dependencies for local package .

Error: ParsedYamlException: line 3, column 10: Unsupported value for "version". Could not parse "abc".
  ╷
3 │ version: abc
  │          ^^^
  ╵
''';

    expect(apitoolNeedsNetwork(output), isFalse);
  });

  test('a comparison that pub.dev answered with a server error needs network access', () {
    // What `dart_apitool diff --old pub://adapty_flutter/4.4.1` prints, stdout then stderr, when the server answers
    // 503 to every try of pub.
    const output = '''
Preparing adapty_flutter:4.4.1
Downloading
503 Service Unavailable trying to find package adapty_flutter at https://pub.dev.

Error: Exception: 503 Service Unavailable trying to find package adapty_flutter at https://pub.dev.
''';

    expect(apitoolNeedsNetwork(output), isTrue);
    expect(apitoolNeedsNetwork(output.replaceAll('503 Service Unavailable', '500 Internal Server Error')), isTrue);
  });

  test('a comparison with a release that pub.dev does not have does not ask for network access', () {
    const output = '''
Preparing adapty_flutter:4.4.1
Downloading
Package not available (could not find package adapty_flutter at https://pub.dev).

Error: Exception: Package not available (could not find package adapty_flutter at https://pub.dev).
''';

    expect(apitoolNeedsNetwork(output), isFalse);
  });

  group('a run that could not reach pub.dev', () {
    const socketError = 'Error: Exception: Got socket error trying to find package adapty_flutter at https://pub.dev.';

    /// A run of dart_apitool that gives [results] in turn, and the number of runs so far.
    (Future<ProcessResult> Function(), int Function()) runs(List<(int, String)> results) {
      var count = 0;
      return (
        () async {
          final (exitCode, stderr) = results[count++];
          return ProcessResult(count, exitCode, 'run $count', stderr);
        },
        () => count,
      );
    }

    test('is run again until it succeeds, and each failed run is told of', () async {
      final (run, count) = runs([(1, socketError), (1, socketError), (0, '')]);
      final told = <(int, Object?)>[];

      final result = await retryNetworkFailures(
        run,
        pause: Duration.zero,
        onRetry: (attempt, failed) => told.add((attempt, failed.stdout)),
      );

      expect((result.exitCode, result.stdout, count()), (0, 'run 3', 3));
      expect(told, [(1, 'run 1'), (2, 'run 2')]);
    });

    test('is given up after the attempts, with the last failure', () async {
      final (run, count) = runs([for (var i = 0; i < 5; i++) (1, socketError)]);

      final result = await retryNetworkFailures(run, attempts: 3, pause: Duration.zero);

      expect((result.exitCode, result.stdout, count()), (1, 'run 3', 3));
    });

    test('is not run again when it succeeds or fails for another reason', () async {
      for (final first in [(0, ''), (1, 'Error: Exception: Package not available')]) {
        final (run, count) = runs([first, (0, '')]);

        final result = await retryNetworkFailures(run, pause: Duration.zero);

        expect((result.exitCode, count()), (first.$1, 1), reason: first.$2);
      }
    });
  });

  test('a comparison that could not reach pub.dev fails as a failure of the network, not of the API', () {
    final result = evaluateApiGate(
      const ApiGateInput(
        pubspecVersion: '4.4.0',
        lastRelease: '4.4.0',
        releaseLine: false,
        snapshotMatches: true,
        diff: null,
        diffError: 'Got socket error trying to find package adapty_flutter at https://pub.dev.',
        diffNeedsNetwork: true,
      ),
    );

    expect(
      result.failures.single,
      'cannot compare with adapty_flutter 4.4.0: Got socket error trying to find package adapty_flutter at '
      'https://pub.dev. (pub.dev could not be reached: the network or pub.dev failed, not the API; run the check '
      'again)',
    );
  });

  test('the reason of a failure on a broken pubspec is the error, not the frame drawn under it', () {
    const stderr = '''
Error: ParsedYamlException: line 3, column 10: Unsupported value for "version". Could not parse "abc".
  ╷
3 │ version: abc
  │          ^^^
  ╵
''';

    expect(
      apitoolFailureReason(stdout: 'Preparing .\n', stderr: stderr),
      'ParsedYamlException: line 3, column 10: Unsupported value for "version". Could not parse "abc".',
    );
  });

  test('the reason of a failure without the network is the error pub reported', () {
    const stderr = '''
Error: Exception: Got socket error trying to find package meta at https://pub.dev.
Failed to update packages.
''';

    expect(
      apitoolFailureReason(stdout: 'Resolving dependencies...\n', stderr: stderr),
      'Got socket error trying to find package meta at https://pub.dev.',
    );
  });

  test('the reason of a failure without an error line is the last line of stderr', () {
    expect(
      apitoolFailureReason(stdout: 'Preparing .\n', stderr: 'Resolving dependencies...\nno versions match\n'),
      'no versions match',
    );
  });

  test('the reason of a failure that printed nothing to stderr is the last line of stdout', () {
    expect(apitoolFailureReason(stdout: 'Preparing .\npackage not found\n\n', stderr: ''), 'package not found');
  });

  test('the tail of a failed run is the end of stderr under a heading', () {
    final stderr = [for (var line = 1; line <= 50; line++) 'line $line'].join('\n');

    expect(
      apitoolOutputTail(stdout: 'Preparing .\nCopying sources from .\n', stderr: '$stderr\n\n'),
      ['--- dart_apitool stderr (last 40 lines) ---', for (var line = 11; line <= 50; line++) 'line $line'].join('\n'),
    );
  });

  test('the tail of a failed run that printed nothing to stderr is the end of stdout', () {
    expect(
      apitoolOutputTail(stdout: 'Preparing .\n  package not found\n', stderr: '\n'),
      '--- dart_apitool stdout (last 2 lines) ---\nPreparing .\n  package not found',
    );
  });

  test('the tail of a failed run that printed nothing is empty', () {
    expect(apitoolOutputTail(stdout: '', stderr: ''), '');
  });

  test('the tail of a failed copy of the plugin keeps the rsync error that names the file', () {
    // What `dart_apitool extract` prints to stderr when Flutter fails to copy the plugin into
    // build/ios/SourcePackages: the reason line names no file, the rsync line under the file list does.
    const rsyncError =
        'rsync(76202): error: /tmp/repo/build/ios/SourcePackages/repo/zz_victim.txt: open (2) in /tmp/repo: '
        'No such file or directory';
    final stderr = [
      'Error: Exception: Failed to copy plugin adapty_flutter: ',
      'Transfer starting: 8860 files',
      'deleting zz_victim.txt',
      for (var file = 1; file <= 60; file++) 'build/ios/SourcePackages/repo/lib/src/file_$file.dart',
      '',
      'sent 105435184 bytes  received 20406 bytes  71929329 bytes/sec',
      'total size is 436399894  speedup is 4.14',
      '',
      rsyncError,
      '',
      '',
    ].join('\n');

    final tail = apitoolOutputTail(stdout: 'Preparing .\nCopying sources from .\n', stderr: stderr);

    expect(tail.split('\n'), hasLength(41));
    expect(tail.split('\n').first, '--- dart_apitool stderr (last 40 lines) ---');
    expect(tail.split('\n').last, rsyncError);
    expect(apitoolFailureReason(stdout: '', stderr: stderr), 'Failed to copy plugin adapty_flutter:');
  });
}
