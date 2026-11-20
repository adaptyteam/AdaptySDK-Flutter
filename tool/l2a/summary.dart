import 'dart:io';

import 'src/summary.dart';

// Usage, from the repository root: dart run tool/l2a/summary.dart <run directory>
//
// Prints the summary of a run of tool/l2a/ci/ios.sh or android.sh as Markdown: the steps, the counters of the
// probe, the cases by the basis of their expectation, the denied cases, what the probe does not cover, the
// answers other than expected, the resolved iOS SDK and the class of the failure (infra or probe). An iOS SDK
// other than the one the expectations were recorded on is a warning (native-moved), not a failure.
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
  final run = L2aRun.parse(
    steps: steps,
    info: read('info.tsv'),
    logs: {
      for (final line in steps.split('\n'))
        if (line.split('\t') case [final name, 'probe', ...] when File('$dir/$name.log').existsSync())
          name: read('$name.log'),
    },
  );
  stdout.write(run.toMarkdown());
  if (run.failureClass != null) exit(1);
}
