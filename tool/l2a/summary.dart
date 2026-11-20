import 'dart:io';

import 'package:yaml/yaml.dart';

import 'src/summary.dart';

// Usage, from the repository root: dart run tool/l2a/summary.dart <run directory>
// (the root matters: probed is read from integration_test_app/l2a_expectations.yaml relative to it)
//
// Prints the summary of a run of tool/l2a/ci/ios.sh or android.sh as Markdown: the steps, the counters of the
// probe, the cases by the basis of their expectation, the denied cases, what the probe does not cover, the
// answers other than expected, the resolved iOS SDK and the class of the failure (infra or probe). An iOS SDK
// other than the one the expectations were recorded on is a warning (native-moved), and so is an iOS runtime or an
// Xcode other than theirs (runtime-moved, from probed of integration_test_app/l2a_expectations.yaml), and so is an
// L2A_WARNING line a step printed (a native log check that saw only part of the log); none of them is a failure.
//
// Exit codes: 0 — the run is green; 1 — the run is red, or the directory could not be read.
void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/l2a/summary.dart <run directory>');
    exit(1);
  }
  final dir = args.single;
  String read(String name) {
    final file = File('$dir/$name');
    return file.existsSync() ? file.readAsStringSync() : '';
  }

  final steps = read('steps.tsv');
  final expectations = File('integration_test_app/l2a_expectations.yaml');
  final probed = expectations.existsSync() ? loadYaml(expectations.readAsStringSync()) : null;
  final run = L2aRun.parse(
    steps: steps,
    info: read('info.tsv'),
    logs: {
      for (final line in steps.split('\n'))
        if (line.split('\t') case [final name, 'probe', ...] when File('$dir/$name.log').existsSync())
          name: read('$name.log'),
    },
    probed: {
      if (probed is YamlMap && probed['probed'] is YamlMap)
        for (final MapEntry(:key, :value) in (probed['probed'] as YamlMap).entries) '$key': '$value',
    },
  );
  stdout.write(run.toMarkdown());
  if (run.failureClass != null) exit(1);
}
