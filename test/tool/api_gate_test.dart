import 'dart:convert';

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

  test('a release that is not on pub.dev yet fails with the reason', () {
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

    expect(
      result.failures.single,
      contains('cannot compare with adapty_flutter 4.4.0: it is not on pub.dev yet (package not found)'),
    );
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
  });
}
