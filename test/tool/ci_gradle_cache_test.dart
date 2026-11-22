// The android-unit job of ci.yml runs the JVM tests of the Android plugin through the Gradle of the example app. Without
// a cache every run downloads the Gradle distribution and the Android Gradle plugin with its dependencies again, which
// takes most of the time the job is given, and the job would still pass until a slow runner hits its timeout.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const _job = 'android-unit';

/// Whether [step] keeps the Gradle caches between runs: actions/setup-java with `cache: gradle`, or actions/cache with
/// the Gradle caches among its paths.
bool _keepsGradleCaches(YamlMap step) {
  final uses = '${step['uses']}';
  final inputs = step['with'];
  if (inputs is! YamlMap) return false;
  if (uses.startsWith('actions/setup-java@')) return inputs['cache'] == 'gradle';
  if (uses.startsWith('actions/cache@')) {
    return '${inputs['path']}'.split('\n').map((path) => path.trim()).contains('~/.gradle/caches');
  }
  return false;
}

/// The steps of [job] in the workflow [text].
List<YamlMap> _steps(String text, String job) {
  final jobs = (loadYaml(text) as YamlMap)['jobs'] as YamlMap;
  return [for (final step in (jobs[job] as YamlMap)['steps'] as YamlList) step as YamlMap];
}

void main() {
  test('the android-unit job keeps the Gradle caches between runs', () {
    final steps = _steps(File('.github/workflows/ci.yml').readAsStringSync(), _job);
    expect(steps.where(_keepsGradleCaches).toList(), isNotEmpty, reason: '$_job: no step keeps the Gradle caches');
  });

  group('a step', () {
    YamlMap step(String text) => loadYaml(text) as YamlMap;

    test('keeps the Gradle caches when setup-java caches gradle or actions/cache keeps ~/.gradle/caches', () {
      expect(
        _keepsGradleCaches(step('{uses: actions/setup-java@v4, with: {java-version: "17", cache: gradle}}')),
        isTrue,
      );
      expect(
        _keepsGradleCaches(step('{uses: actions/cache@v4, with: {path: "~/.npm\\n~/.gradle/caches\\n"}}')),
        isTrue,
      );
    });

    test('does not keep them when setup-java caches nothing or another tool, or the cache keeps other paths', () {
      expect(_keepsGradleCaches(step('{uses: actions/setup-java@v4, with: {java-version: "17"}}')), isFalse);
      expect(_keepsGradleCaches(step('{uses: actions/setup-java@v4, with: {cache: maven}}')), isFalse);
      expect(_keepsGradleCaches(step('{uses: actions/cache@v4, with: {path: ~/.gradle/wrapper}}')), isFalse);
      expect(_keepsGradleCaches(step('{uses: other/setup-java@v4, with: {cache: gradle}}')), isFalse);
      expect(_keepsGradleCaches(step('{run: ./gradlew test}')), isFalse);
    });
  });
}
